@Tags(['db'])
library;

import 'dart:io';

import 'package:duitku/data/app_state.dart';
import 'package:duitku/data/database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

/// Attacks the backup import path.
///
/// Importing a file replaces the only copy of the user's data, and the file
/// comes from outside the app (a picker, a share, a download). So the question
/// is not whether a good file imports — it is whether a bad file can be tricked
/// into being accepted, and whether a failure leaves the real data intact.
void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    ffi.sqfliteFfiInit();
    ffi.databaseFactory = ffi.databaseFactoryFfi;
  });

  late Directory tmp;
  late AppState state;
  late String liveDbPath;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp('duitku_sec_backup');
    liveDbPath = p.join(tmp.path, 'live.db');
    state = await AppState.bootstrapForTests(dbPath: liveDbPath);
  });

  tearDown(() async {
    await state.dispose();
    AppDatabase.overridePath(null);
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  /// Writes a SQLite file with [statements] and returns its path.
  Future<String> makeDb(String name, List<String> statements) async {
    final path = p.join(tmp.path, name);
    final db = await ffi.databaseFactory.openDatabase(
      path,
      options: ffi.OpenDatabaseOptions(
        version: 1,
        onCreate: (d, _) async {
          for (final s in statements) {
            await d.execute(s);
          }
        },
      ),
    );
    await db.close();
    return path;
  }

  test('a random non-database file is refused', () async {
    final junk = File(p.join(tmp.path, 'not-a-db.bin'));
    await junk.writeAsString('this is definitely not a sqlite database' * 50);

    await expectLater(state.importBackup(junk), throwsA(anything));

    // The real data must still be readable after the refusal.
    expect(state.wallets, isNotEmpty,
        reason: 'a rejected import must leave the live data alone');
  });

  test('a database with the right tables but wrong columns is refused',
      () async {
    // This is the attack the table-name-only check missed: correct names, so
    // it looked like a backup, but every later query would crash.
    final path = await makeDb('wrong-columns.db', [
      'CREATE TABLE wallets (id INTEGER PRIMARY KEY, name TEXT)',
      'CREATE TABLE categories (id INTEGER PRIMARY KEY, name TEXT)',
      'CREATE TABLE transactions (id INTEGER PRIMARY KEY, amount REAL)',
    ]);

    await expectLater(state.importBackup(File(path)), throwsA(anything));
    expect(state.wallets, isNotEmpty);
  });

  test('an empty but valid sqlite file is refused', () async {
    final path = await makeDb('empty.db', [
      'CREATE TABLE unrelated (x INTEGER)',
    ]);

    await expectLater(state.importBackup(File(path)), throwsA(anything));
    expect(state.wallets, isNotEmpty);
  });

  test('a missing file is refused', () async {
    await expectLater(
      state.importBackup(File(p.join(tmp.path, 'nope.db'))),
      throwsA(anything),
    );
  });

  test('a genuine backup is accepted and actually restores', () async {
    // The happy path, to prove the checks above are not simply refusing
    // everything. The file is built with the app's real schema so it is
    // exactly what a real backup looks like.
    await state.addWallet('Dompet Uji', 0, 0);

    // The test database lives at a known path; a real backup is a copy of it.
    // The -wal and -shm sidecars are copied too, because recent writes live
    // there until SQLite checkpoints them back into the main file.
    final good = p.join(tmp.path, 'genuine.db');
    await File(liveDbPath).copy(good);
    for (final suffix in ['-wal', '-shm']) {
      final side = File('$liveDbPath$suffix');
      if (await side.exists()) await side.copy('$good$suffix');
    }

    // Change the live data so the restore is observable.
    await state.wipeEverything();
    expect(state.wallets.map((w) => w.name), isNot(contains('Dompet Uji')));

    await state.importBackup(File(good));

    final names = state.wallets.map((w) => w.name).toList();
    expect(names, contains('Dompet Uji'),
        reason: 'a genuine backup must restore');
  });
}
