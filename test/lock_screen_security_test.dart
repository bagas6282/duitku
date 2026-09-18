@Tags(['db'])
library;

import 'dart:io';

import 'package:duitku/core/formatters.dart';
import 'package:duitku/core/strings.dart';
import 'package:duitku/data/app_state.dart';
import 'package:duitku/data/database.dart';
import 'package:duitku/features/auth/lock_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

/// Attacks the lock screen.
///
/// The lock exists to keep the app's contents away from whoever is holding an
/// unlocked phone. The hole this covers: the "Forgot?" button used to delete
/// the passcode and call `unlock()` with no check at all, so two taps opened
/// every transaction. These tests fail if that ever comes back.
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
    tmp = await Directory.systemTemp.createTemp('duitku_lock');
    state = await AppState.bootstrapForTests(dbPath: p.join(tmp.path, 'l.db'));
  });

  tearDown(() async {
    await state.dispose();
    AppDatabase.overridePath(null);
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(
          const Duration(milliseconds: 120),
        ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  Future<void> pumpLock(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          home: LanguageScope(
            language: AppLanguage.fromCode('id'),
            child: const LockScreen(),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets('wrong passcode does not unlock', (tester) async {
    await state.setPin('4821');
    state.lock();
    await pumpLock(tester);

    for (final d in ['1', '2', '3', '4']) {
      await tester.tap(find.text(d));
      await tester.pump();
    }
    await settle(tester);

    expect(state.locked, isTrue,
        reason: 'a wrong passcode must never open the app');
    expect(find.text('Sandi salah'), findsOneWidget);
  });

  testWidgets('correct passcode unlocks', (tester) async {
    await state.setPin('4821');
    state.lock();
    await pumpLock(tester);

    for (final d in ['4', '8', '2', '1']) {
      await tester.tap(find.text(d));
      await tester.pump();
    }
    await settle(tester);

    expect(state.locked, isFalse, reason: 'the real passcode must work');
  });

  testWidgets('Forgot? does NOT remove the passcode without proof',
      (tester) async {
    // The regression guard. Previously this path called setPin(null) +
    // unlock() straight away.
    await state.setPin('4821');
    state.lock();
    await pumpLock(tester);

    await tester.tap(find.text('Lupa sandi?'));
    await settle(tester);

    // A confirmation step must appear, and it must ask for the passcode.
    expect(find.text('Konfirmasi sandi kamu'), findsOneWidget,
        reason: 'removing the passcode must require confirmation');

    // Cancelling changes nothing.
    await tester.tap(find.text('Batal'));
    await settle(tester);

    expect(state.pinEnabled, isTrue, reason: 'the passcode must survive');
    expect(state.locked, isTrue,
        reason: 'cancelling must not open the app');
    expect(state.checkPin('4821'), isTrue,
        reason: 'the original passcode must still be valid');
  });

  testWidgets('Forgot? refuses a wrong passcode in the confirm step',
      (tester) async {
    await state.setPin('4821');
    state.lock();
    await pumpLock(tester);

    await tester.tap(find.text('Lupa sandi?'));
    await settle(tester);

    await tester.enterText(find.byType(TextField), '0000');
    await tester.pump();
    await tester.tap(find.text('Hapus'));
    await settle(tester);

    expect(state.pinEnabled, isTrue,
        reason: 'a wrong passcode must not remove the lock');
    expect(state.locked, isTrue, reason: 'and must not open the app');
  });

  testWidgets('Forgot? removes the passcode when the real one is given',
      (tester) async {
    // The legitimate path, so the check above is not simply blocking
    // everything.
    await state.setPin('4821');
    state.lock();
    await pumpLock(tester);

    await tester.tap(find.text('Lupa sandi?'));
    await settle(tester);

    await tester.enterText(find.byType(TextField), '4821');
    await tester.pump();
    await tester.tap(find.text('Hapus'));
    await settle(tester);
    await settle(tester);

    expect(state.pinEnabled, isFalse, reason: 'proof was given, so it clears');
    expect(state.locked, isFalse);
  });
}
