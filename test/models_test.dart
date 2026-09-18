import 'package:duitku/core/formatters.dart';
import 'package:duitku/core/strings.dart';
import 'package:duitku/data/models/budget.dart';
import 'package:duitku/data/models/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Formatters.init();
  });

  group('Formatters', () {
    test('currency renders rupiah with dot separators and no decimals', () {
      expect(Formatters.currency(1250000), 'Rp1.250.000');
      expect(Formatters.currency(0), 'Rp0');
      expect(Formatters.currency(999), 'Rp999');
    });

    test('thousands strips the symbol so text fields can own the prefix', () {
      expect(Formatters.thousands(1250000), '1.250.000');
      expect(Formatters.thousands(0), '0');
    });

    test('signed prefixes income with + and expense with -', () {
      expect(Formatters.signed(50000, isIncome: true), '+Rp50.000');
      expect(Formatters.signed(50000, isIncome: false), '-Rp50.000');
    });

    test('signedCurrency marks the sign and keeps zero neutral', () {
      expect(Formatters.signedCurrency(250000), '+Rp250.000');
      expect(Formatters.signedCurrency(-250000), '-Rp250.000');
      expect(Formatters.signedCurrency(0), 'Rp0');
    });

    test('dayKey buckets rows by calendar day', () {
      expect(Formatters.dayKey(DateTime(2026, 9, 5)), '2026-09-05');
      expect(Formatters.dayKey(DateTime(2026, 12, 31)), '2026-12-31');
    });

    test('dayHeader labels today and yesterday in the active language', () {
      final now = DateTime.now();
      // The app now starts in Indonesian, so the default expectations are
      // Indonesian; the English branch is asserted explicitly to prove the
      // labels really follow the language instead of being hardcoded.
      expect(Formatters.dayHeader(now), 'Hari ini');
      expect(
        Formatters.dayHeader(now.subtract(const Duration(days: 1))),
        'Kemarin',
      );

      Formatters.setLanguage(AppLanguage.english);
      addTearDown(() => Formatters.setLanguage(AppLanguage.indonesian));
      expect(Formatters.dayHeader(now), 'Today');
      expect(
        Formatters.dayHeader(now.subtract(const Duration(days: 1))),
        'Yesterday',
      );

      // A fixed old date must render as a date, never as "N days ago".
      final old = DateTime(2020, 1, 15);
      expect(Formatters.dayHeader(old), isNot(contains('ago')));
    });

    test('isSameDay ignores the time component', () {
      expect(
        Formatters.isSameDay(
          DateTime(2026, 9, 17, 1, 30),
          DateTime(2026, 9, 17, 23, 45),
        ),
        isTrue,
      );
      expect(
        Formatters.isSameDay(
          DateTime(2026, 9, 17),
          DateTime(2026, 9, 18),
        ),
        isFalse,
      );
    });
  });

  group('Transaction', () {
    Transaction tx(TxType type, num amount) => Transaction(
          id: 1,
          type: type,
          amount: amount,
          categoryId: 1,
          walletId: 1,
          date: DateTime(2026, 9, 17),
        );

    test('signedAmount is positive for income, negative for expense', () {
      expect(tx(TxType.income, 100000).signedAmount, 100000);
      expect(tx(TxType.expense, 100000).signedAmount, -100000);
    });

    test('transfers are economically neutral', () {
      final t = tx(TxType.transfer, 500000);
      expect(t.signedAmount, 0);
      expect(t.isIncome, isFalse);
      expect(t.isTransfer, isTrue);
    });

    test('round-trips through the map representation', () {
      final original = Transaction(
        id: 7,
        type: TxType.expense,
        amount: 42500,
        categoryId: 3,
        walletId: 2,
        date: DateTime(2026, 9, 17, 14, 30),
        note: 'Kopi',
      );
      final restored = Transaction.fromMap(original.toMap());
      expect(restored.id, original.id);
      expect(restored.type, original.type);
      expect(restored.amount, original.amount);
      expect(restored.categoryId, original.categoryId);
      expect(restored.walletId, original.walletId);
      expect(restored.date, original.date);
      expect(restored.note, original.note);
    });

    test('toMap omits id when unsaved so SQLite assigns one', () {
      final unsaved = Transaction(
        type: TxType.expense,
        amount: 1000,
        categoryId: 1,
        walletId: 1,
        date: DateTime(2026, 9, 17),
      );
      expect(unsaved.toMap().containsKey('id'), isFalse);
    });

    test('copyWith preserves fields the caller did not touch', () {
      final base = tx(TxType.expense, 10000);
      final edited = base.copyWith(amount: 20000);
      expect(edited.amount, 20000);
      expect(edited.categoryId, base.categoryId);
      expect(edited.walletId, base.walletId);
      expect(edited.date, base.date);
    });
  });

  group('SavingsGoal', () {
    test('ratio clamps to 1 once the target is met', () {
      const goal = SavingsGoal(
        id: 1,
        name: 'Laptop',
        targetAmount: 10000000,
        savedAmount: 12000000,
        colorIndex: 0,
      );
      expect(goal.ratio, 1.0);
      expect(goal.isComplete, isTrue);
      expect(goal.remaining, 0);
    });

    test('a zero target does not divide by zero', () {
      const goal = SavingsGoal(
        id: 1,
        name: 'Empty',
        targetAmount: 0,
        savedAmount: 0,
        colorIndex: 0,
      );
      expect(goal.ratio, 0);
      expect(goal.requiredMonthly(), isNull);
    });

    test('requiredMonthly spreads the remainder across the deadline', () {
      final goal = SavingsGoal(
        id: 1,
        name: 'Trip',
        targetAmount: 12000000,
        savedAmount: 0,
        colorIndex: 0,
        deadline: DateTime.now().add(const Duration(days: 320)),
      );
      final monthly = goal.requiredMonthly();
      expect(monthly, isNotNull);
      expect(monthly! > 0, isTrue);
      // 12M over ~10-11 months lands in a sane band, not a wild number.
      expect(monthly, greaterThan(900000));
      expect(monthly, lessThan(1500000));
    });
  });

  group('Budget', () {
    test('round-trips through the map representation', () {
      const b = Budget(
        id: 4,
        categoryId: 2,
        limitAmount: 750000,
        monthKey: '2026-09',
      );
      final restored = Budget.fromMap(b.toMap());
      expect(restored.id, b.id);
      expect(restored.categoryId, b.categoryId);
      expect(restored.limitAmount, b.limitAmount);
      expect(restored.monthKey, b.monthKey);
    });

    test('toMap omits id for a new budget', () {
      const fresh = Budget(
        categoryId: 2,
        limitAmount: 750000,
        monthKey: '2026-09',
      );
      expect(fresh.toMap().containsKey('id'), isFalse);
    });
  });
}
