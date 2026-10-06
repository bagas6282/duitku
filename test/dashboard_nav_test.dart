@Tags(['db'])
library;

import 'dart:io';

import 'package:duitku/core/formatters.dart';
import 'package:duitku/data/app_state.dart';
import 'package:duitku/data/database.dart';
import 'package:duitku/features/budget/budget_editor.dart';
import 'package:duitku/features/dashboard/dashboard_page.dart';
import 'package:duitku/features/settings/settings_page.dart';
import 'package:duitku/features/transactions/transaction_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

/// Drives the home screen the way a person does: taps the buttons that are
/// visible on the dashboard and checks something actually happens.
///
/// The "Set a budget" button spent a long time looking dead. The data layer was
/// fine the whole time — it was navigation: the button called
/// `Navigator.pushNamed(context, '/budget')` while the app registered no named
/// routes at all, so every tap threw. Nothing caught it because the other tests
/// mount pages directly instead of going through the buttons.
///
/// `every pushNamed targets a registered route` is the guard against that
/// class of bug coming back: adding a named-route call without registering it
/// fails the suite instead of shipping.
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
    tmp = await Directory.systemTemp.createTemp('duitku_dash_nav');
    state = await AppState.bootstrapForTests(dbPath: p.join(tmp.path, 'nav.db'));
  });

  tearDown(() async {
    await state.dispose();
    AppDatabase.overridePath(null);
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  /// Lets real SQLite queries finish before painting.
  ///
  /// `pumpAndSettle` is unusable: a progress indicator animates forever and
  /// would time out. `runAsync` hands control back to the event loop, which is
  /// what the ffi-backed database needs to complete.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(
          const Duration(milliseconds: 120),
        ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  /// Mounts the real dashboard, wrapped the way `main.dart` wraps it: the
  /// state comes from a Provider, and the page supplies its own AppBar.
  ///
  /// The viewport is set to a real phone size (390x844) rather than the
  /// 800x600 default. The dashboard is a lazy SliverList and the budget editor
  /// a lazy ListView, so on the small default viewport the budget card and the
  /// save button are simply never built — which is the whole reason the
  /// original dead-button bug slipped past the suite for so long.
  Future<void> pumpDashboard(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          home: const Scaffold(body: DashboardPage()),
        ),
      ),
    );
    await settle(tester);
    await settle(tester);
  }

  testWidgets('the settings button opens the settings screen', (tester) async {
    await pumpDashboard(tester);

    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The settings page lists these switches; the dashboard shows none of them.
    expect(find.text('Bahasa'), findsWidgets);
    expect(find.byType(SettingsPage), findsOneWidget);
  });

  testWidgets('the empty budget card offers a working Set a budget button',
      (tester) async {
    await pumpDashboard(tester);

    final setBudget = find.text('Atur anggaran');
    expect(setBudget, findsOneWidget,
        reason: 'a user with no budget must be offered a way to make one');

    await tester.tap(setBudget);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The editor opened, which is what the dead button never did.
    expect(find.byType(BudgetEditor), findsOneWidget);
  });

  testWidgets('setting a budget from the dashboard actually saves it',
      (tester) async {
    await pumpDashboard(tester);

    await tester.tap(find.text('Atur anggaran'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Type an amount into the editor's field, pick a category (the editor
    // refuses to save without one) and press the FilledButton that saves.
    await tester.enterText(find.byType(TextField).first, '250000');
    await tester.pump();
    await settle(tester);

    await tester.tap(find.text('Makan & Minum').first);
    await tester.pump();
    await settle(tester);

    await tester.tap(find.byType(FilledButton).first);
    await settle(tester);
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 500));
    await settle(tester);

    // Read it back from the database, not from the screen: proving the write
    // landed is the only thing that matters here.
    final saved = await tester.runAsync(
      () => state.repo.budgetsFor(state.monthKey),
    );
    expect(saved, isNotNull);
    expect(saved!, isNotEmpty, reason: 'the budget must be persisted');
    expect(saved.first.limitAmount, 250000);

    // And the dashboard now shows a real progress bar instead of the empty
    // call to action.
    expect(find.text('Atur anggaran'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsWidgets);
  });

  testWidgets('the add-transaction button is reachable without scrolling',
      (tester) async {
    // The complaint was that the button had to be scrolled to. It now lives in
    // the Scaffold's bottomNavigationBar, so it is on screen the moment the
    // form opens and stays there while the form is scrolled.
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(home: TransactionEditor()),
      ),
    );
    await settle(tester);
    await settle(tester);

    final save = find.byType(FilledButton);
    expect(save, findsOneWidget, reason: 'the save button must exist');
    expect(tester.getRect(save).bottom, lessThanOrEqualTo(844.0),
        reason: 'it must sit inside the viewport, not below the fold');

    // Scroll the form hard and confirm the button has not moved: that is the
    // difference between a pinned button and one that rides the content.
    final before = tester.getRect(save);
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await settle(tester);
    expect(tester.getRect(save), before,
        reason: 'a pinned button must not scroll with the form');
  });

  testWidgets('tapping add transaction when amount is empty scrolls up and prompts',
      (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(home: TransactionEditor()),
      ),
    );
    await settle(tester);

    // Scroll down
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await settle(tester);

    // Tap the pinned button
    final save = find.byType(FilledButton);
    await tester.tap(save);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // SnackBar appears prompting user
    expect(find.text('Isi jumlahnya dulu'), findsOneWidget);
  });

  testWidgets('tapping scan receipt button opens camera/gallery options',
      (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(home: TransactionEditor()),
      ),
    );
    await settle(tester);

    // Scan button exists and is visible
    final scanBadge = find.text('Pindai struk');
    expect(scanBadge, findsWidgets);

    // Tap scan button
    await tester.tap(scanBadge.first);
    await settle(tester);

    // Modal sheet opens with both camera and gallery options
    expect(find.text('Ambil foto'), findsOneWidget);
    expect(find.text('Pilih dari galeri'), findsOneWidget);
  });

  testWidgets('every pushNamed in the app targets a registered route',
      (tester) async {
    // There is no `routes:` table and no `onGenerateRoute` anywhere in this
    // app, so ANY pushNamed call is a guaranteed runtime failure. This test
    // exists to fail loudly the moment someone adds one.
    final offenders = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

    for (final f in files) {
      final src = f.readAsStringSync();
      final lines = src.split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('pushNamed') &&
            !lines[i].trimLeft().startsWith('//')) {
          offenders.add('${f.path}:${i + 1}  ${lines[i].trim()}');
        }
      }
    }

    expect(offenders, isEmpty,
        reason: 'pushNamed needs a registered route; use\n'
            '    Navigator.of(context).push(MaterialPageRoute(...))\n'
            'instead — see the Settings and Budget buttons on the dashboard.\n'
            'Offending call sites:\n${offenders.join('\n')}');
  });
}
