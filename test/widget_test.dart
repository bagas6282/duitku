import 'package:duitku/core/formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Smoke test: proves the formatters boot and a widget tree that uses them
/// builds without throwing. Full navigation is covered by the manual
/// checklist in the README, since the real app needs a device database.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Formatters.init();
  });

  testWidgets('Indonesian dates render once locale data is loaded',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Text(Formatters.currency(1250000)),
              Text(Formatters.longDate(DateTime(2026, 9, 17))),
              Text(Formatters.monthYear(DateTime(2026, 9, 1))),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Rp1.250.000'), findsOneWidget);
    expect(find.textContaining('2026'), findsNWidgets(2));
  });
}
