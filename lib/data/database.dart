import 'dart:async';

import 'package:flutter/material.dart';
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
    await syncDefaultCategoryIcons(db);
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
    await syncDefaultCategoryIcons(db);
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

    batch.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        avatar_url TEXT,
        created_at INTEGER NOT NULL
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
    batch.execute(
      'CREATE INDEX idx_users_email ON users (email)',
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
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        avatar_url TEXT,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_users_email ON users (email)',
    );
  }

  /// Defaults for a fresh install: three wallets and a starter category set
  /// covering the usual student budget lines.
  /// Writes the starter wallets and categories.
  ///
  /// Public because the reset-data path re-runs it after emptying the tables,
  /// so a wiped app still opens with usable defaults rather than nothing.
  static Future<void> seedDefaults(DatabaseExecutor db) => _seed(db);

  static Future<void> _seed(DatabaseExecutor db) async {
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
    // Names match the Indonesian labels in L (Health→Kesehatan, etc.).
    final categories = <(String, int, int, bool)>[
      ('Food & Drink', Icons.restaurant_rounded.codePoint, 0, false),
      ('Transport', Icons.directions_car_rounded.codePoint, 1, false),
      ('Tuition', Icons.school_rounded.codePoint, 3, false),
      ('Books', Icons.menu_book_rounded.codePoint, 4, false),
      ('Entertainment', Icons.movie_rounded.codePoint, 5, false),
      ('Health', Icons.medical_services_rounded.codePoint, 6, false),
      ('Rent', Icons.home_rounded.codePoint, 2, false),
      ('Shopping', Icons.shopping_bag_rounded.codePoint, 7, false),
      ('Other', Icons.more_horiz_rounded.codePoint, 1, false),
      ('Salary', Icons.payments_rounded.codePoint, 0, true),
      ('Allowance', Icons.savings_rounded.codePoint, 4, true),
      ('Freelance', Icons.work_rounded.codePoint, 5, true),
      ('Gift', Icons.card_giftcard_rounded.codePoint, 6, true),
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

  /// Rewrites default-category icons on every launch so an older install
  /// (wrong glyph: folder, star, TV, question mark) picks up the remap
  /// without wiping user data. Only rows that still use the seed names
  /// are touched; a renamed category is left alone.
  static Future<void> syncDefaultCategoryIcons(Database db) async {
    final map = <String, int>{
      'Food & Drink': Icons.restaurant_rounded.codePoint,
      'Transport': Icons.directions_car_rounded.codePoint,
      'Tuition': Icons.school_rounded.codePoint,
      'Books': Icons.menu_book_rounded.codePoint,
      'Health': Icons.medical_services_rounded.codePoint,
      'Rent': Icons.home_rounded.codePoint,
      'Shopping': Icons.shopping_bag_rounded.codePoint,
      'Other': Icons.more_horiz_rounded.codePoint,
      'Salary': Icons.payments_rounded.codePoint,
      'Allowance': Icons.savings_rounded.codePoint,
    };
    for (final e in map.entries) {
      await db.update(
        'categories',
        {'icon_code': e.value},
        where: 'name = ?',
        whereArgs: [e.key],
      );
    }
  }

  /// Full-file checkpoint before a destructive import.
  Future<void> checkpoint() => db.rawQuery('PRAGMA wal_checkpoint(FULL)');

  Future<void> close() => db.close();
}
