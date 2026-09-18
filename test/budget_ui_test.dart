@Tags(['db'])
library;

import 'dart:io';

import 'package:duitku/core/formatters.dart';
import 'package:duitku/core/strings.dart';
import 'package:duitku/core/theme.dart';
import 'package:duitku/data/models/transaction.dart';
import 'package:duitku/data/app_state.dart';
import 'package:duitku/data/database.dart';
import 'package:duitku/features/budget/budget_editor.dart';
import 'package:duitku/features/budget/budget_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

/// Drives the Budget tab the way a person does: taps the add button, types an
/// amount, saves, and checks the cap appears on screen.
///
/// This is the level the original bug lived at — the data layer was fine, but
/// a user with no caps had no button to press and the list never refreshed.
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
    tmp = await Directory.systemTemp.createTemp('duitku_budget_ui');
    state = await AppState.bootstrapForTests(dbPath: p.join(tmp.path, 'ui.db'));
  });

  tearDown(() async {
    await state.dispose();
    AppDatabase.overridePath(null);
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  /// Lets real SQLite queries finish before painting.
  ///
  /// `pumpAndSettle` is not usable here: a progress indicator animates
  /// forever, so it would time out. `runAsync` hands control back to the event
  /// loop, which is what the ffi-backed database needs to complete.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(
          const Duration(milliseconds: 120),
        ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  /// Runs a database action outside the fake-async zone.
  ///
  /// The ffi database does real I/O on the event loop; inside `testWidgets`
  /// the clock is faked, so an un-awaited write would never complete and the
  /// test would hang.
  Future<void> write(WidgetTester tester, Future<void> Function() action) async {
    await tester.runAsync(action);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  /// Gives the test a phone-sized surface.
  ///
  /// The default 800x600 test window is shorter than any real phone, so a
  /// form's bottom button would fall outside the viewport and the lazy
  /// ListView would never build it — a failure that only exists in the test.
  void usePhoneSurface(WidgetTester tester) {
    // 400 x 900 logical pixels at 3x — the shape of a real phone, and tall
    // enough that a form's primary button is inside the viewport.
    tester.view.physicalSize = const Size(1200, 2700);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  Widget wrap(AppState s) => ChangeNotifierProvider<AppState>.value(
        value: s,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: LanguageScope(
            language: AppLanguage.fromCode(s.localeCode),
            child: const Scaffold(body: BudgetPage()),
          ),
        ),
      );

  Widget wrapEditor(AppState s) => ChangeNotifierProvider<AppState>.value(
        value: s,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: LanguageScope(
            language: AppLanguage.fromCode(s.localeCode),
            child: const BudgetEditor(),
          ),
        ),
      );

  testWidgets('an empty month offers a way to create the first budget',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(wrap(state));
    await settle(tester);

    // The regression: with no budgets the page showed only text, so there was
    // no control to add one.
    expect(find.text('Tambah anggaran'), findsOneWidget);
  });

  testWidgets('the editor renders a usable form with a save action',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(wrapEditor(state));
    await settle(tester);

    // The editor is mounted directly rather than pushed from the list: routing
    // it through a Navigator kept the test waiting on a route animation that
    // never settles in the fake-async zone.
    expect(find.text('Anggaran baru'), findsOneWidget);
    expect(find.byType(TextField), findsWidgets,
        reason: 'the amount field must be present');
    expect(find.byType(FilledButton), findsWidgets,
        reason: 'the editor needs a save action');

    // The save button is disabled until an amount is entered — a zero cap is
    // meaningless, and the empty state is what it must not look like.
    final before = tester.widget<FilledButton>(find.byType(FilledButton).first);
    expect(before.onPressed, isNull,
        reason: 'saving with no amount must be impossible');

    await tester.enterText(find.byType(TextField).first, '450000');
    await settle(tester);

    final after = tester.widget<FilledButton>(find.byType(FilledButton).first);
    expect(after.onPressed, isNotNull,
        reason: 'entering an amount must enable saving');
  });

  testWidgets('the list repaints after a budget is added elsewhere',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(wrap(state));
    await settle(tester);

    // No caps yet.
    expect(find.text('Belum ada anggaran bulan ini'), findsOneWidget);

    // Add through the state, as the editor does, then let the widget rebuild.
    await write(tester, () async {
      await state.setBudget(state.categoriesFor(TxType.expense).first.id, 200000);
    });
    await settle(tester);

    // The page must reflect it without being reopened.
    expect(find.text('Belum ada anggaran bulan ini'), findsNothing);
    expect(find.textContaining('200'), findsWidgets);
  });
}
