@Tags(['db'])
library;

import 'dart:io';

import 'package:duitku/core/formatters.dart';
import 'package:duitku/data/app_state.dart';
import 'package:duitku/data/database.dart';
import 'package:duitku/data/models/transaction.dart';
import 'package:duitku/features/dashboard/dashboard_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

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
    tmp = await Directory.systemTemp.createTemp('duitku_period_test');
    state = await AppState.bootstrapForTests(dbPath: p.join(tmp.path, 'period.db'));
  });

  tearDown(() async {
    await state.dispose();
    AppDatabase.overridePath(null);
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('daily vs monthly calculation computes correctly in AppState', () async {
    await state.setMonth(DateTime(2026, 9));
    final catId = state.categories.first.id;
    final walletId = state.wallets.first.id;

    // Add transaction on Sep 18, 2026
    await state.addTransaction(
      Transaction(
        type: TxType.expense,
        amount: 25000,
        categoryId: catId,
        walletId: walletId,
        date: DateTime(2026, 9, 18, 10, 30),
      ),
    );

    // Add transaction on Sep 19, 2026
    await state.addTransaction(
      Transaction(
        type: TxType.expense,
        amount: 50000,
        categoryId: catId,
        walletId: walletId,
        date: DateTime(2026, 9, 19, 14, 0),
      ),
    );

    // Default is monthly mode
    expect(state.periodMode, PeriodMode.monthly);
    expect(state.monthExpense, 75000);
    expect(state.periodExpense, 75000);

    // Switch to daily mode for Sep 18
    await state.setSelectedDate(DateTime(2026, 9, 18));
    state.setPeriodMode(PeriodMode.daily);

    expect(state.isDaily, isTrue);
    expect(state.dailyExpense, 25000);
    expect(state.periodExpense, 25000);

    // Step to next day (Sep 19)
    await state.shiftPeriod(1);
    expect(state.selectedDate.day, 19);
    expect(state.dailyExpense, 50000);
    expect(state.periodExpense, 50000);

    // Step back to Sep 18
    await state.shiftPeriod(-1);
    expect(state.selectedDate.day, 18);
    expect(state.periodExpense, 25000);

    // Switch back to monthly
    state.setPeriodMode(PeriodMode.monthly);
    expect(state.periodExpense, 75000);
  });

  testWidgets('switching between Harian and Bulanan works on dashboard UI', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(
          home: Scaffold(body: DashboardPage()),
        ),
      ),
    );

    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
    await tester.pumpAndSettle();

    // Verify both toggle buttons exist
    expect(find.text('Harian (Per Tanggal)'), findsOneWidget);
    expect(find.text('Bulanan (Per Bulan)'), findsOneWidget);

    // Tap Harian
    await tester.tap(find.text('Harian (Per Tanggal)'));
    await tester.pumpAndSettle();

    expect(state.isDaily, isTrue);

    // Tap Bulanan
    await tester.tap(find.text('Bulanan (Per Bulan)'));
    await tester.pumpAndSettle();

    expect(state.isDaily, isFalse);
  });
}
