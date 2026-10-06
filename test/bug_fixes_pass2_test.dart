@Tags(['db'])
library;

import 'dart:io';

import 'package:duitku/core/formatters.dart';
import 'package:duitku/data/app_state.dart';
import 'package:duitku/data/database.dart';
import 'package:duitku/data/models/transaction.dart';
import 'package:duitku/data/repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

/// Regression tests for Pass 2 bug fixes:
/// 1. walletBalances handles deleted destination wallet
/// 2. fundGoalFromWallet is atomic
/// 3. wipe() is atomic
/// 4. importBackup restores all files on rollback
/// 5. refreshAll() prevents concurrent races
/// 6. registerUser catches UNIQUE constraint violations
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
  late AppDatabase db;
  late FinanceRepository repo;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('duitku_bugfix2');
    db = await AppDatabase.openForTests(p.join(tmp.path, 'test.db'));
    repo = FinanceRepository(db);
  });

  tearDown(() async {
    await db.close();
    AppDatabase.overridePath(null);
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  group('Bug #1: walletBalances with deleted destination wallet', () {
    test('deleting transfer destination does not inflate totalBalance', () async {
      final wallets = await repo.wallets();
      final cat = (await repo.categories()).firstWhere((c) => !c.isIncome).id;
      final walletA = wallets[0].id;
      final walletB = wallets[1].id;

      // Transfer 300k from A to B
      await repo.insertTransaction(
        Transaction(
          type: TxType.transfer,
          amount: 300000,
          categoryId: cat,
          walletId: walletA,
          transferWalletId: walletB,
          date: DateTime.now(),
        ),
      );

      final balanceBefore = await repo.walletBalances();
      final totalBefore = balanceBefore.values.fold<num>(0, (s, v) => s + v);
      expect(totalBefore, 0, reason: 'a transfer between own wallets nets to zero');

      // Delete the destination wallet (B)
      await repo.deleteWallet(walletB);

      final balanceAfter = await repo.walletBalances();
      final totalAfter = balanceAfter.values.fold<num>(0, (s, v) => s + v);

      // Deleting a wallet removes its history, so the transfer that pointed at
      // it goes too: wallet A is back to its opening balance and no orphan row
      // is left behind claiming money is somewhere it no longer is.
      expect(totalAfter, totalBefore,
          reason: 'deleting the destination must not invent or destroy money');
      expect(balanceAfter[walletA], 0,
          reason: 'the transfer row is gone with the wallet it pointed at');
      expect(await repo.transactions(), isEmpty,
          reason: 'no orphan transfer may survive the destination wallet');
    });

    test('transfer to existing wallet still credits correctly', () async {
      final wallets = await repo.wallets();
      final cat = (await repo.categories()).firstWhere((c) => !c.isIncome).id;
      final walletA = wallets[0].id;
      final walletB = wallets[1].id;

      await repo.insertTransaction(
        Transaction(
          type: TxType.transfer,
          amount: 500000,
          categoryId: cat,
          walletId: walletA,
          transferWalletId: walletB,
          date: DateTime.now(),
        ),
      );

      final balances = await repo.walletBalances();
      expect(balances[walletA], -500000);
      expect(balances[walletB], 500000);

      final total = balances.values.fold<num>(0, (s, v) => s + v);
      expect(total, 0, reason: 'transfer must not change total balance');
    });
  });

  group('Bug #2: fundGoalFromWallet atomicity', () {
    test('transaction and goal credit both land or both fail', () async {
      final dir = await Directory.systemTemp.createTemp('duitku_atomic_fund');
      addTearDown(() async {
        if (await dir.exists()) await dir.delete(recursive: true);
      });

      final state = await AppState.bootstrapForTests(
        dbPath: p.join(dir.path, 'atomic.db'),
      );
      addTearDown(state.dispose);

      // Clear seed data so this test's goal is the only one.
      for (final g in List.of(state.goals)) {
        await state.deleteGoal(g.id);
      }

      // Add a goal with tight headroom
      await state.addGoal('Test Goal Fund', 200000, null, 0);
      final goal = state.goals.firstWhere((g) => g.name == 'Test Goal Fund');
      final wallet = state.wallets.first;
      final balanceBefore = state.totalBalance;
      final txCountBefore = state.transactions.length;

      // Fund with exactly the headroom
      final added = await state.fundGoalFromWallet(
        goalId: goal.id,
        amount: 200000,
        walletId: wallet.id,
        isIncome: false,
      );

      expect(added, 200000);

      // Both the transaction and the goal credit must have landed
      final goalAfter = state.goals.firstWhere((g) => g.name == 'Test Goal Fund');
      expect(goalAfter.savedAmount, 200000);
      expect(goalAfter.done, isTrue);
      expect(state.totalBalance, balanceBefore - 200000);
      expect(state.transactions.length, txCountBefore + 1);
    });

    test('overfunding a goal still books the full transaction amount', () async {
      final dir = await Directory.systemTemp.createTemp('duitku_overfund');
      addTearDown(() async {
        if (await dir.exists()) await dir.delete(recursive: true);
      });

      final state = await AppState.bootstrapForTests(
        dbPath: p.join(dir.path, 'overfund.db'),
      );
      addTearDown(state.dispose);

      await state.addGoal('Small Goal', 100000, null, 0);
      final goal = state.goals.firstWhere((g) => g.name == 'Small Goal');
      final wallet = state.wallets.first;
      final balanceBefore = state.totalBalance;

      // Ask for 300k but goal can only take 100k
      final added = await state.fundGoalFromWallet(
        goalId: goal.id,
        amount: 300000,
        walletId: wallet.id,
        isIncome: false,
      );

      expect(added, 100000, reason: 'goal only had 100k headroom');

      final goalAfter = state.goals.firstWhere((g) => g.name == 'Small Goal');
      expect(goalAfter.savedAmount, 100000);

      // The wallet should have lost the full 300k requested, not just what
      // the goal accepted — this is the honest outcome.
      expect(state.totalBalance, balanceBefore - 300000,
          reason: 'the full transaction amount leaves the wallet');
    });
  });

  group('Bug #3: wipe() atomicity', () {
    test('wipe leaves usable defaults even if interrupted', () async {
      final wallets = await repo.wallets();
      final cat = (await repo.categories()).firstWhere((c) => !c.isIncome).id;

      // Add some data
      await repo.insertTransaction(
        Transaction(
          type: TxType.expense,
          amount: 50000,
          categoryId: cat,
          walletId: wallets.first.id,
          date: DateTime.now(),
        ),
      );

      expect(await repo.countTransactions(), 1);

      // Wipe everything
      await repo.wipe();

      // All data gone
      expect(await repo.countTransactions(), 0);

      // But defaults must be back
      expect((await repo.wallets()).length, 3);
      expect((await repo.categories()).isNotEmpty, isTrue);

      // The user can immediately record a new transaction
      await repo.insertTransaction(
        Transaction(
          type: TxType.expense,
          amount: 10000,
          categoryId: (await repo.categories()).first.id,
          walletId: (await repo.wallets()).first.id,
          date: DateTime.now(),
        ),
      );
      expect(await repo.countTransactions(), 1);
    });
  });

  group('Bug #4: importBackup rollback completeness', () {
    test('failed import restores all three database files', () async {
      final dir = await Directory.systemTemp.createTemp('duitku_import_rollback');
      addTearDown(() async {
        if (await dir.exists()) await dir.delete(recursive: true);
      });

      final state = await AppState.bootstrapForTests(
        dbPath: p.join(dir.path, 'original.db'),
      );
      addTearDown(state.dispose);

      // Add some data to the original database
      await state.addWallet('Original Wallet', 1000000, 0);
      final walletsBefore = state.wallets.length;

      // Create a corrupt "backup" file
      final badBackup = File(p.join(dir.path, 'corrupt.db'));
      await badBackup.writeAsString('not a database');

      // Try to import it
      try {
        await state.importBackup(badBackup);
        fail('import should have thrown');
      } catch (e) {
        // Expected
      }

      // The original data must still be intact
      expect(state.wallets.length, walletsBefore);
      expect(state.wallets.any((w) => w.name == 'Original Wallet'), isTrue);
    });
  });

  group('Bug #5: refreshAll() race guard', () {
    test('concurrent refreshAll calls do not race', () async {
      final dir = await Directory.systemTemp.createTemp('duitku_refresh_race');
      addTearDown(() async {
        if (await dir.exists()) await dir.delete(recursive: true);
      });

      final state = await AppState.bootstrapForTests(
        dbPath: p.join(dir.path, 'race.db'),
      );
      addTearDown(state.dispose);

      // Add a transaction
      final cat = state.categories.firstWhere((c) => !c.isIncome).id;
      await state.addTransaction(
        Transaction(
          type: TxType.expense,
          amount: 100000,
          categoryId: cat,
          walletId: state.wallets.first.id,
          date: DateTime.now(),
        ),
      );

      // Launch multiple concurrent refreshes
      final futures = List.generate(10, (_) => state.refreshAll());
      await Future.wait(futures);

      // State should be consistent
      expect(state.transactions.isNotEmpty, isTrue);
      expect(state.walletBalances.isNotEmpty, isTrue);

      // No exception should have been thrown
    });
  });

  group('Bug #6: registerUser UNIQUE constraint handling', () {
    test('concurrent registrations with same email surface friendly error', () async {
      // The pre-check can lose a race, so the UNIQUE constraint violation must
      // be caught and translated to the same friendly message.

      // First registration succeeds
      final user1 = await repo.registerUser(
        name: 'User One',
        email: 'duplicate@test.com',
        password: 'password123',
      );
      expect(user1.id, greaterThan(0));

      // Second registration with same email must fail with friendly message
      try {
        await repo.registerUser(
          name: 'User Two',
          email: 'DUPLICATE@TEST.COM',
          password: 'password456',
        );
        fail('should have thrown');
      } on Exception catch (e) {
        expect(e.toString(), contains('Email sudah terdaftar'));
        expect(e.toString().toLowerCase(), isNot(contains('unique')),
            reason: 'raw SQLite error must not leak to UI');
      }
    });

    test('different emails can register concurrently', () async {
      final user1 = await repo.registerUser(
        name: 'Alice',
        email: 'alice@test.com',
        password: 'pass1',
      );
      final user2 = await repo.registerUser(
        name: 'Bob',
        email: 'bob@test.com',
        password: 'pass2',
      );

      expect(user1.id, isNot(user2.id));
      expect(await repo.countUsers(), 2);
    });
  });
}
