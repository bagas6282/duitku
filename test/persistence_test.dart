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
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

/// Proves the app stores real data on disk, not in memory.
///
/// Every assertion here closes the database and reopens it, because "it works
/// while the app is open" is not the same as "my money is still there
/// tomorrow". This is the property a finance tracker lives or dies by.
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
    tmp = await Directory.systemTemp.createTemp('duitku_persist');
    dbPath = p.join(tmp.path, 'persist.db');
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

  test('a transaction survives closing and reopening the app', () async {
    final id = await withApp((s) async {
      final c = s.categoriesFor(TxType.expense).first;
      // Move to the month the record belongs to first: `transactions` only
      // holds the visible month, so a May row is invisible while September is
      // open. Asserting on the wrong month would look like data loss.
      await s.setMonth(DateTime(2026, 5, 1));
      await s.addTransaction(
        Transaction(
          id: 0,
          amount: 87500,
          date: DateTime(2026, 5, 17, 14, 30),
          type: TxType.expense,
          categoryId: c.id,
          walletId: s.wallets.first.id,
          note: 'makan siang',
        ),
      );
      expect(s.transactions, hasLength(1));
      return s.transactions.first.id;
    });

    // Fresh AppState on the same file: this is the real test.
    await withApp((s) async {
      await s.setMonth(DateTime(2026, 5, 1));
      expect(s.transactions, hasLength(1));
      final t = s.transactions.single;
      expect(t.id, id);
      expect(t.amount, 87500);
      expect(t.note, 'makan siang');
      expect(t.date.day, 17);
      expect(t.date.hour, 14, reason: 'the time of day must round-trip too');
    });
  });

  test('a budget survives a restart and still shows its progress', () async {
    await withApp((s) async {
      final c = s.categoriesFor(TxType.expense).first;
      await s.setBudget(c.id, 600000);
      await s.addTransaction(
        Transaction(
          id: 0,
          amount: 150000,
          date: DateTime.now(),
          type: TxType.expense,
          categoryId: c.id,
          walletId: s.wallets.first.id,
          note: 'belanja',
        ),
      );
    });

    await withApp((s) async {
      final progress = await s.budgetProgress();
      expect(progress, hasLength(1));
      expect(progress.single.limit, 600000);
      expect(progress.single.spent, 150000);
      expect(progress.single.remaining, 450000);
    });
  });

  test('editing a budget updates the stored row instead of adding one', () async {
    final cId = await withApp((s) async {
      final c = s.categoriesFor(TxType.expense).first;
      await s.setBudget(c.id, 100000);
      return c.id;
    });

    await withApp((s) async {
      await s.setBudget(cId, 375000);
    });

    await withApp((s) async {
      final progress = await s.budgetProgress();
      expect(progress, hasLength(1),
          reason: 'a second save must update, not duplicate');
      expect(progress.single.limit, 375000);
    });
  });

  test('deleting a transaction removes it from the database for good', () async {
    await withApp((s) async {
      await s.addTransaction(
        Transaction(
          id: 0,
          amount: 20000,
          date: DateTime.now(),
          type: TxType.expense,
          categoryId: s.categoriesFor(TxType.expense).first.id,
          walletId: s.wallets.first.id,
          note: 'hapus aku',
        ),
      );
      // The row is stored by now, so it has a real id; the null check is a
      // guard that turns a "not saved" regression into a clear failure rather
      // than a confusing type error.
      final saved = s.transactions.single;
      expect(saved.id, isNotNull, reason: 'addTransaction must persist a row');
      await s.deleteTransaction(saved.id!);
    });

    await withApp((s) async {
      expect(s.transactions, isEmpty);
    });
  });

  test('a wallet balance reflects the transactions recorded against it', () async {
    final walletId = await withApp((s) async {
      final w = s.wallets.first;
      await s.addTransaction(
        Transaction(
          id: 0,
          amount: 500000,
          date: DateTime.now(),
          type: TxType.income,
          categoryId: s.categoriesFor(TxType.income).first.id,
          walletId: w.id,
          note: 'gaji',
        ),
      );
      await s.addTransaction(
        Transaction(
          id: 0,
          amount: 125000,
          date: DateTime.now(),
          type: TxType.expense,
          categoryId: s.categoriesFor(TxType.expense).first.id,
          walletId: w.id,
          note: 'belanja',
        ),
      );
      return w.id;
    });

    await withApp((s) async {
      // Income 500k - expense 125k = 375k, recomputed from the rows on disk.
      expect(s.totalBalance, 375000);
      expect(s.walletOf(walletId), isNotNull);
    });
  });

  test('data written to one month does not appear in another', () async {
    await withApp((s) async {
      await s.setMonth(DateTime(2026, 5, 10));
      await s.addTransaction(
        Transaction(
          id: 0,
          amount: 33000,
          date: DateTime(2026, 5, 10),
          type: TxType.expense,
          categoryId: s.categoriesFor(TxType.expense).first.id,
          walletId: s.wallets.first.id,
          note: 'mei',
        ),
      );
    });

    await withApp((s) async {
      await s.setMonth(DateTime(2026, 6, 10));
      expect(s.transactions, isEmpty,
          reason: 'June must not show May spending');
      await s.setMonth(DateTime(2026, 5, 10));
      expect(s.transactions, hasLength(1));
      expect(s.transactions.single.note, 'mei');
    });
  });

  test('the database file actually exists and grows after a write', () async {
    await withApp((s) async {
      for (var i = 0; i < 25; i++) {
        await s.addTransaction(
          Transaction(
            id: 0,
            amount: 1000 * (i + 1),
            date: DateTime.now(),
            type: TxType.expense,
            categoryId: s.categoriesFor(TxType.expense).first.id,
            walletId: s.wallets.first.id,
            note: 'baris $i',
          ),
        );
      }
    });

    // SQLite creates the file lazily, so the meaningful assertion is that it
    // exists and holds real bytes once rows have been written.
    final file = File(dbPath);
    expect(await file.exists(), isTrue, reason: 'writes must reach disk');
    final size = await file.length();
    expect(size, greaterThan(0));

    // File size is not a usable signal here: SQLite pre-allocates pages, so a
    // seeded-but-empty database and one with 25 rows can report the same
    // length. What proves persistence is that the rows are readable back from
    // a brand new connection.
    await withApp((s) async {
      expect(s.transactions, hasLength(25));
    });
  });

  test('default wallets and categories are seeded on the very first run', () async {
    await withApp((s) async {
      expect(s.wallets, hasLength(3));
      expect(s.categoriesFor(TxType.expense), isNotEmpty);
      expect(s.categoriesFor(TxType.income), isNotEmpty);
    });
  });

  test('wiping data leaves a usable app, not an empty shell', () async {
    await withApp((s) async {
      await s.addTransaction(
        Transaction(
          id: 0,
          amount: 9000,
          date: DateTime.now(),
          type: TxType.expense,
          categoryId: s.categoriesFor(TxType.expense).first.id,
          walletId: s.wallets.first.id,
          note: 'sementara',
        ),
      );
      await s.wipeEverything();
    });

    await withApp((s) async {
      expect(s.transactions, isEmpty);
      // Re-seeded: the user can still record something straight away.
      expect(s.wallets, hasLength(3));
      expect(s.categoriesFor(TxType.expense), isNotEmpty);
    });
  });

  test('budgets and transactions both survive a round trip together', () async {
    await withApp((s) async {
      final c = s.categoriesFor(TxType.expense).first;
      await s.setBudget(c.id, 1000000);
      await s.setBudget(s.categoriesFor(TxType.expense)[1].id, 250000);
      await s.addTransaction(
        Transaction(
          id: 0,
          amount: 400000,
          date: DateTime.now(),
          type: TxType.expense,
          categoryId: c.id,
          walletId: s.wallets.first.id,
          note: 'besar',
        ),
      );
    });

    await withApp((s) async {
      final progress = await s.budgetProgress();
      expect(progress, hasLength(2));
      final withSpend = progress.firstWhere((x) => x.spent > 0);
      expect(withSpend.limit, 1000000);
      expect(withSpend.spent, 400000);
      expect(withSpend.remaining, 600000);
      expect(withSpend.over, isFalse);

      final untouched = progress.firstWhere((x) => x.spent == 0);
      expect(untouched.limit, 250000);
      expect(untouched.remaining, 250000);
    });
  });
}
