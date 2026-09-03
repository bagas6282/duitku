import 'package:sqflite/sqflite.dart' hide Transaction;

import 'database.dart';
import 'models/budget.dart';
import 'models/category.dart';
import 'models/transaction.dart';
import 'models/wallet.dart';

/// Every query the app runs, in one place.
///
/// Keeping SQL out of widgets means the same statements back the UI, the CSV
/// export and the recurring-transaction job, so totals never disagree.
class FinanceRepository {
  FinanceRepository(this._db);

  final AppDatabase _db;
  Database get _d => _db.db;

  // ---------------------------------------------------------------- wallets

  Future<List<Wallet>> wallets({bool includeArchived = false}) async {
    final rows = await _d.query(
      'wallets',
      where: includeArchived ? null : 'archived = 0',
      orderBy: 'id ASC',
    );
    return rows.map(Wallet.fromMap).toList();
  }

  Future<int> insertWallet(Wallet w) =>
      _d.insert('wallets', w.copyWith(id: 0).toMap()..remove('id'));

  Future<void> updateWallet(Wallet w) => _d.update(
        'wallets',
        w.toMap(),
        where: 'id = ?',
        whereArgs: [w.id],
      );

  Future<void> deleteWallet(int id) =>
      _d.delete('wallets', where: 'id = ?', whereArgs: [id]);

  // ------------------------------------------------------------- categories

  Future<List<Category>> categories({
    bool? isIncome,
    bool includeArchived = false,
  }) async {
    final clauses = <String>[];
    final args = <Object?>[];
    if (isIncome != null) {
      clauses.add('is_income = ?');
      args.add(isIncome ? 1 : 0);
    }
    if (!includeArchived) clauses.add('archived = 0');

    final rows = await _d.query(
      'categories',
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'is_income ASC, name ASC',
    );
    return rows.map(Category.fromMap).toList();
  }

  Future<int> insertCategory(Category c) =>
      _d.insert('categories', c.copyWith(id: 0).toMap()..remove('id'));

  Future<void> updateCategory(Category c) => _d.update(
        'categories',
        c.toMap(),
        where: 'id = ?',
        whereArgs: [c.id],
      );

  /// Soft delete. Transactions keep their category label; the category just
  /// stops appearing in pickers.
  Future<void> archiveCategory(int id) => _d.update(
        'categories',
        {'archived': 1},
        where: 'id = ?',
        whereArgs: [id],
      );

  // ----------------------------------------------------------- transactions

  Future<List<Transaction>> transactions({
    DateTime? from,
    DateTime? to,
    int? categoryId,
    int? walletId,
    String? query,
    num? minAmount,
    num? maxAmount,
    int? limit,
  }) async {
    final clauses = <String>[];
    final args = <Object?>[];

    if (from != null) {
      clauses.add('occurred_at >= ?');
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      // Exclusive upper bound: callers pass the first instant of the period
      // *after* the one they want, so nothing at the boundary is lost.
      clauses.add('occurred_at < ?');
      args.add(to.millisecondsSinceEpoch);
    }
    if (categoryId != null) {
      clauses.add('category_id = ?');
      args.add(categoryId);
    }
    if (walletId != null) {
      clauses.add('(wallet_id = ? OR transfer_wallet_id = ?)');
      args.addAll([walletId, walletId]);
    }
    if (query != null && query.trim().isNotEmpty) {
      clauses.add('note LIKE ?');
      args.add('%${query.trim()}%');
    }
    if (minAmount != null) {
      clauses.add('amount >= ?');
      args.add(minAmount);
    }
    if (maxAmount != null) {
      clauses.add('amount <= ?');
      args.add(maxAmount);
    }

    final rows = await _d.query(
      'transactions',
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'occurred_at DESC, id DESC',
      limit: limit,
    );
    return rows.map(Transaction.fromMap).toList();
  }

  /// Single row by primary key. Used by the undo path, which needs the full
  /// record even when the transaction is outside the currently loaded month.
  Future<List<Transaction>> transactionsById(int id) async {
    final rows = await _d.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.map(Transaction.fromMap).toList();
  }

  Future<int> insertTransaction(Transaction t) =>
      _d.insert('transactions', t.toMap()..remove('id'));


  Future<void> updateTransaction(Transaction t) => _d.update(
        'transactions',
        t.toMap()..remove('id'),
        where: 'id = ?',
        whereArgs: [t.id],
      );

  Future<void> deleteTransaction(int id) =>
      _d.delete('transactions', where: 'id = ?', whereArgs: [id]);

  /// Restores a deleted row with its original id, which undo needs.
  ///
  /// Deliberately NOT `ConflictAlgorithm.replace`: replace deletes the row
  /// holding that id before inserting, so a stale undo could destroy a
  /// different transaction that reused the id. Ignoring the conflict instead
  /// makes a double-tapped undo a no-op, which is the safe failure mode.
  Future<void> restoreTransaction(Transaction t) => _d.insert(
        'transactions',
        t.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

  /// Sum of a signed column over a window. Used by every summary card.
  Future<num> sumFor(
    TxType type, {
    required DateTime from,
    required DateTime to,
    int? walletId,
  }) async {
    final clauses = ['type = ?', 'occurred_at >= ?', 'occurred_at < ?'];
    final args = <Object?>[
      type.name,
      from.millisecondsSinceEpoch,
      to.millisecondsSinceEpoch,
    ];
    if (walletId != null) {
      clauses.add('wallet_id = ?');
      args.add(walletId);
    }
    final r = await _d.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS total FROM transactions '
      'WHERE ${clauses.join(' AND ')}',
      args,
    );
    return (r.first['total'] as num?) ?? 0;
  }

  /// Live balance per wallet: opening balance plus every signed movement.
  Future<Map<int, num>> walletBalances() async {
    final ws = await wallets();
    final r = await _d.rawQuery('''
      SELECT wallet_id, type, SUM(amount) AS total
      FROM transactions GROUP BY wallet_id, type
    ''');

    final balances = {for (final w in ws) w.id: w.openingBalance};

    for (final row in r) {
      final id = row['wallet_id'] as int;
      final type = row['type'] as String;
      final total = (row['total'] as num?) ?? 0;
      switch (type) {
        case 'income':
          balances[id] = (balances[id] ?? 0) + total;
        case 'expense':
          balances[id] = (balances[id] ?? 0) - total;
        case 'transfer':
          balances[id] = (balances[id] ?? 0) - total;
      }
    }

    // Transfers credit the destination wallet, which the GROUP BY above
    // cannot see because the row is keyed by the source wallet.
    final incoming = await _d.rawQuery('''
      SELECT transfer_wallet_id AS wid, SUM(amount) AS total
      FROM transactions
      WHERE type = 'transfer' AND transfer_wallet_id IS NOT NULL
      GROUP BY transfer_wallet_id
    ''');
    for (final row in incoming) {
      final id = row['wid'] as int;
      balances[id] = (balances[id] ?? 0) + ((row['total'] as num?) ?? 0);
    }

    return balances;
  }

  /// Spend rolled up per category for a window — the pie chart's data source.
  Future<Map<int, num>> spendByCategory({
    required DateTime from,
    required DateTime to,
    required TxType type,
  }) async {
    final r = await _d.rawQuery(
      '''
      SELECT category_id, SUM(amount) AS total
      FROM transactions
      WHERE type = ? AND occurred_at >= ? AND occurred_at < ?
        AND category_id IS NOT NULL
      GROUP BY category_id
      ''',
      [type.name, from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
    );
    return {
      for (final row in r)
        row['category_id'] as int: (row['total'] as num?) ?? 0,
    };
  }

  /// Daily income/expense totals for the trend line over the last [days].
  Future<List<DailyTotal>> dailyTotals({
    required DateTime from,
    required DateTime to,
  }) async {
    final r = await _d.rawQuery(
      '''
      SELECT occurred_at, type, amount FROM transactions
      WHERE occurred_at >= ? AND occurred_at < ? AND type != 'transfer'
      ''',
      [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
    );

    final byDay = <String, DailyTotal>{};
    for (final row in r) {
      final d = DateTime.fromMillisecondsSinceEpoch(row['occurred_at'] as int);
      final key = '${d.year}-${d.month}-${d.day}';
      final entry = byDay.putIfAbsent(
        key,
        () => DailyTotal(day: DateTime(d.year, d.month, d.day)),
      );
      if (row['type'] == 'income') {
        entry.income += (row['amount'] as num);
      } else {
        entry.expense += (row['amount'] as num);
      }
    }

    final list = byDay.values.toList()..sort((a, b) => a.day.compareTo(b.day));
    return list;
  }

  // ---------------------------------------------------------------- budgets

  Future<List<Budget>> budgetsFor(String monthKey) async {
    final rows = await _d.query(
      'budgets',
      where: 'month_key = ?',
      whereArgs: [monthKey],
    );
    return rows.map(Budget.fromMap).toList();
  }

  /// Inserts or replaces the cap for a category in a month.
  Future<void> setBudget({
    required int categoryId,
    required num limit,
    required String monthKey,
  }) async {
    await _d.insert(
      'budgets',
      {
        'category_id': categoryId,
        'limit_amount': limit,
        'month_key': monthKey,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteBudget(int id) =>
      _d.delete('budgets', where: 'id = ?', whereArgs: [id]);

  /// Adds a cap, or overwrites the existing one for the same category+month.
  ///
  /// Budgets are identified by (category, month) — that pair carries a UNIQUE
  /// constraint — so a plain INSERT would throw the moment the user re-set a
  /// cap for a category that already had one. Using REPLACE makes the call
  /// idempotent, which is what every caller actually wants.
  Future<int> insertBudget(Budget b) => _d.insert(
        'budgets',
        b.toMap()..remove('id'),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<void> updateBudget(Budget b) => _d.update(
        'budgets',
        b.toMap()..remove('id'),
        where: 'id = ?',
        whereArgs: [b.id],
      );

  /// Copies last month's caps into [toMonth]. Existing entries are kept.
  Future<int> copyBudgetsFrom({
    required String fromMonth,
    required String toMonth,
  }) async {
    final source = await budgetsFor(fromMonth);
    if (source.isEmpty) return 0;

    var copied = 0;
    for (final b in source) {
      final existing = await _d.query(
        'budgets',
        where: 'category_id = ? AND month_key = ?',
        whereArgs: [b.categoryId, toMonth],
      );
      if (existing.isNotEmpty) continue;
      await setBudget(
        categoryId: b.categoryId,
        limit: b.limitAmount,
        monthKey: toMonth,
      );
      copied++;
    }
    return copied;
  }

  // ------------------------------------------------------------------ goals

  Future<List<SavingsGoal>> goals() async {
    final rows = await _d.query('goals', orderBy: 'done ASC, id DESC');
    return rows.map(SavingsGoal.fromMap).toList();
  }

  /// Reads the row straight from the database rather than from any cached list.
  ///
  /// The funding flow depends on the freshest `saved_amount` to work out how
  /// much headroom is left, and a stale copy would let a goal overshoot.
  Future<SavingsGoal?> goalByIdAsync(int id) async {
    final rows = await _d.query('goals', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : SavingsGoal.fromMap(rows.first);
  }

  Future<int> insertGoal(SavingsGoal g) =>
      _d.insert('goals', g.copyWith(id: 0).toMap()..remove('id'));

  Future<void> updateGoal(SavingsGoal g) => _d.update(
        'goals',
        g.toMap(),
        where: 'id = ?',
        whereArgs: [g.id],
      );

  Future<void> deleteGoal(int id) =>
      _d.delete('goals', where: 'id = ?', whereArgs: [id]);

  /// Adds a contribution by editing the goal's own column.
  ///
  /// Deliberately **not** routed through [updateGoal]: that writes every field
  /// from the Dart object, so a goal edited from a stale in-memory copy would
  /// silently revert its name, target or deadline. Only the saved amount is the
  /// business of this method.
  ///
  /// Returns the amount actually added. A contribution is clamped at the
  /// target, so a 1.000.000 top-up against 200.000 of headroom reports 200.000
  /// rather than overstating what the user now has put aside.
  Future<num> contributeToGoal(int id, num amount) async {
    if (amount <= 0) return 0;

    return _d.transaction((txn) async {
      final rows = await txn.query('goals', where: 'id = ?', whereArgs: [id]);
      if (rows.isEmpty) return 0;

      final goal = SavingsGoal.fromMap(rows.first);
      final headroom = goal.targetAmount - goal.savedAmount;
      if (headroom <= 0) return 0;

      final added = amount > headroom ? headroom : amount;
      final saved = goal.savedAmount + added;
      await txn.update(
        'goals',
        {'saved_amount': saved, 'done': saved >= goal.targetAmount ? 1 : 0},
        where: 'id = ?',
        whereArgs: [id],
      );
      return added;
    });
  }

  // -------------------------------------------------------------- recurring

  Future<List<RecurringRule>> recurringRules() async {
    final rows = await _d.query('recurring', orderBy: 'next_run_at ASC');
    return rows.map(RecurringRule.fromMap).toList();
  }

  Future<int> insertRecurring(RecurringRule r) =>
      _d.insert('recurring', r.copyWith(id: 0).toMap()..remove('id'));

  Future<void> updateRecurring(RecurringRule r) => _d.update(
        'recurring',
        r.toMap(),
        where: 'id = ?',
        whereArgs: [r.id],
      );

  Future<void> deleteRecurring(int id) =>
      _d.delete('recurring', where: 'id = ?', whereArgs: [id]);

  /// Materializes every rule whose next run has passed.
  ///
  /// Materializes any recurring transactions that have come due.
  ///
  /// Safe to call on every launch: each rule advances its own `nextRunAt`, so
  /// a rule can only ever post each occurrence once. Two guards keep that
  /// promise from breaking:
  ///
  /// * the catch-up window is capped (a rule left dormant for years must not
  ///   post hundreds of rows), and
  /// * `nextRunAt` is *always* written back, even when the cap is hit —
  ///   otherwise the next launch would re-post the same backlog as duplicates.
  Future<int> runDueRecurring({DateTime? now, int maxCatchUp = 36}) async {
    final today = now ?? DateTime.now();
    final rules = await recurringRules();
    var created = 0;

    for (final rule in rules) {
      if (!rule.active) continue;

      var next = rule.nextRunAt;
      var guard = 0;

      while (!next.isAfter(today) && guard < maxCatchUp) {
        await insertTransaction(
          Transaction(
            type: rule.type,
            amount: rule.amount,
            categoryId: rule.categoryId,
            walletId: rule.walletId,
            date: next,
            note: rule.note.isEmpty ? 'Recurring' : rule.note,
            recurringId: rule.id,
          ),
        );
        created++;
        next = _advance(next, rule);
        guard++;
      }

      // If the cap stopped us early, fast-forward the schedule to the next
      // future occurrence instead of leaving it behind today's date.
      if (guard >= maxCatchUp && !next.isAfter(today)) {
        while (!next.isAfter(today)) {
          next = _advance(next, rule);
        }
      }

      if (next != rule.nextRunAt) {
        await updateRecurring(rule.copyWith(nextRunAt: next));
      }
    }
    return created;
  }

  /// Advances a rule to its next occurrence.
  ///
  /// Weekly rules snap to [RecurringRule.weekday] rather than simply adding 7
  /// days: the user picked a weekday in the editor, and honouring it is the
  /// whole point of that control. A rule whose `nextRunAt` drifted off-day
  /// (hand-edited, imported from a backup, or created before the picker
  /// existed) self-corrects on its next step.
  DateTime _advance(DateTime from, RecurringRule rule) {
    if (rule.frequency == RecurFreq.weekly) {
      final target = rule.weekday.clamp(1, 7); // Mon = 1 … Sun = 7
      var days = (target - from.weekday) % 7;
      // Same weekday means "next week", not "today" — otherwise a due rule
      // would advance zero days and post the same occurrence forever.
      if (days <= 0) days += 7;
      final next = from.add(Duration(days: days));
      return DateTime(
        next.year,
        next.month,
        next.day,
        from.hour,
        from.minute,
      );
    }

    // Monthly: clamp to the last valid day so the 31st does not skip February.
    final month = from.month == 12 ? 1 : from.month + 1;
    final year = from.month == 12 ? from.year + 1 : from.year;
    final lastDay = DateTime(year, month + 1, 0).day;
    final day = rule.dayOfMonth.clamp(1, lastDay);
    return DateTime(year, month, day, from.hour, from.minute);
  }

  // ---------------------------------------------------------------- meta

  Future<int> countTransactions() async {
    final r = await _d.rawQuery('SELECT COUNT(*) AS c FROM transactions');
    return (r.first['c'] as int?) ?? 0;
  }

  /// Empties every table, then reinstates the starter wallets and categories.
  ///
  /// Re-seeding matters: without it the user would land on a blank app with no
  /// wallet and no category, unable to record anything until they rebuilt both
  /// by hand.
  Future<void> wipe() async {
    final batch = _d.batch();
    for (final t in [
      'transactions',
      'budgets',
      'recurring',
      'goals',
      'categories',
      'wallets',
    ]) {
      batch.delete(t);
    }
    await batch.commit(noResult: true);

    // Reset AUTOINCREMENT counters so ids start from 1 again.
    await _d.delete('sqlite_sequence');

    await AppDatabase.seedDefaults(_d);
  }
}

/// One point on the trend chart.
class DailyTotal {
  DailyTotal({required this.day});

  final DateTime day;
  num income = 0;
  num expense = 0;

  num get net => income - expense;
}
