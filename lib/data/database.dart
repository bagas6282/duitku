import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Owns the SQLite connection and schema.
///
/// Schema changes go through [_migrate] with an explicit version bump. Seed
/// data (default wallets and categories) lands on first create so a fresh
/// install is usable immediately.
class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static const int _version = 2;

  /// The schema revision this build writes.
  ///
  /// Public so a backup written by a *newer* Duitku can be refused instead of
  /// being imported and then silently corrupted by later writes.
  static int get schemaVersion => _version;
  static const String _fileName = 'duitku.db';

  static Future<AppDatabase> open() async {
    final path = await currentPath();
    final db = await openDatabase(
      path,
      version: _version,
      onConfigure: (d) async {
        // Required for the ON DELETE SET NULL rules below.
        await d.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _create,
      onUpgrade: _migrate,
    );
    return AppDatabase._(db);
  }

  /// Opens an already-materialized file — used by the backup restore path.
  static Future<AppDatabase> openAt(String path) async {
    final db = await openDatabase(
      path,
      version: _version,
      onConfigure: (d) async => d.execute('PRAGMA foreign_keys = ON'),
      onCreate: _create,
      onUpgrade: _migrate,
    );
    return AppDatabase._(db);
  }

  /// Points [open] at a specific file instead of the platform default.
  ///
  /// Only the test suite uses this; production always resolves the path from
  /// the platform. Clearing it with `null` restores normal behaviour.
  static void overridePath(String? path) => _pathOverride = path;

  /// The path of the database that [open] would use right now.
  ///
  /// Backup/restore must write to the same file the app reads from. Deriving it
  /// once here keeps those two from drifting apart.
  static Future<String> currentPath() async {
    return _pathOverride ?? p.join(await getDatabasesPath(), _fileName);
  }

  static String? _pathOverride;

  /// Opens a throwaway database file. Used by tests to bypass `sqflite`'s
  /// platform channel, which is unavailable in the test runner.
  static Future<AppDatabase> openForTests(String path) async {
    _pathOverride = path;
    return open();
  }

  static Future<void> _create(Database db, int version) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE wallets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        opening_balance REAL NOT NULL DEFAULT 0,
        color_index INTEGER NOT NULL DEFAULT 0,
        archived INTEGER NOT NULL DEFAULT 0
      )
    ''');

    batch.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon_code INTEGER NOT NULL,
        color_index INTEGER NOT NULL DEFAULT 0,
        is_income INTEGER NOT NULL DEFAULT 0,
        archived INTEGER NOT NULL DEFAULT 0
      )
    ''');

    batch.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        category_id INTEGER,
        wallet_id INTEGER NOT NULL,
        occurred_at INTEGER NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        recurring_id INTEGER,
        transfer_wallet_id INTEGER,
        created_at INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE SET NULL,
        FOREIGN KEY (wallet_id) REFERENCES wallets (id) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL,
        limit_amount REAL NOT NULL,
        month_key TEXT NOT NULL,
        UNIQUE (category_id, month_key),
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        target_amount REAL NOT NULL,
        saved_amount REAL NOT NULL DEFAULT 0,
        color_index INTEGER NOT NULL DEFAULT 0,
        deadline INTEGER,
        done INTEGER NOT NULL DEFAULT 0
      )
    ''');

    batch.execute('''
      CREATE TABLE recurring (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        category_id INTEGER,
        wallet_id INTEGER NOT NULL,
        frequency TEXT NOT NULL,
        next_run_at INTEGER NOT NULL,
        day_of_month INTEGER NOT NULL DEFAULT 1,
        weekday INTEGER NOT NULL DEFAULT 1,
        note TEXT NOT NULL DEFAULT '',
        active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Hot paths: month filtering, category rollups, wallet lookups.
    batch.execute(
      'CREATE INDEX idx_tx_occurred ON transactions (occurred_at DESC)',
    );
    batch.execute(
      'CREATE INDEX idx_tx_category ON transactions (category_id, occurred_at)',
    );
    batch.execute(
      'CREATE INDEX idx_tx_wallet ON transactions (wallet_id)',
    );
    batch.execute(
      'CREATE INDEX idx_budget_month ON budgets (month_key)',
    );

    await batch.commit(noResult: true);
    await _seed(db);
  }

  static Future<void> _migrate(Database db, int from, int to) async {
    if (from < 2) {
      await db.execute(
        'ALTER TABLE transactions ADD COLUMN created_at INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'UPDATE transactions SET created_at = occurred_at WHERE created_at = 0',
      );
    }
  }

  /// Defaults for a fresh install: three wallets and a starter category set
  /// covering the usual student budget lines.
  /// Writes the starter wallets and categories.
  ///
  /// Public because the reset-data path re-runs it after emptying the tables,
  /// so a wiped app still opens with usable defaults rather than nothing.
  static Future<void> seedDefaults(Database db) => _seed(db);

  static Future<void> _seed(Database db) async {
    final batch = db.batch();

    const wallets = [
      ('Cash', 0.0, 0),
      ('Bank Account', 0.0, 1),
      ('E-Wallet', 0.0, 2),
    ];
    for (final (name, balance, color) in wallets) {
      batch.insert('wallets', {
        'name': name,
        'opening_balance': balance,
        'color_index': color,
      });
    }

    // Codepoints come from Icons.* so no icon font has to be bundled twice.
    const categories = <(String, int, int, bool)>[
      ('Food & Drink', 0xe56c, 0, false),
      ('Transport', 0xe530, 1, false),
      ('Tuition', 0xe80c, 3, false),
      ('Books', 0xe865, 4, false),
      ('Entertainment', 0xe40f, 5, false),
      ('Health', 0xe548, 6, false),
      ('Rent', 0xe88a, 2, false),
      ('Shopping', 0xe8cc, 7, false),
      ('Other', 0xe5d3, 1, false),
      ('Salary', 0xe263, 0, true),
      ('Allowance', 0xe8e5, 4, true),
      ('Freelance', 0xe30a, 5, true),
      ('Gift', 0xe8f6, 6, true),
    ];
    for (final (name, icon, color, income) in categories) {
      batch.insert('categories', {
        'name': name,
        'icon_code': icon,
        'color_index': color,
        'is_income': income ? 1 : 0,
      });
    }

    // One demo goal so the Goals tab is not empty on first launch.
    batch.insert('goals', {
      'name': 'Emergency Fund',
      'target_amount': 5000000,
      'saved_amount': 0,
      'color_index': 0,
    });

    await batch.commit(noResult: true);
  }

  /// Full-file checkpoint before a destructive import.
  Future<void> checkpoint() => db.rawQuery('PRAGMA wal_checkpoint(FULL)');

  Future<void> close() => db.close();
}
