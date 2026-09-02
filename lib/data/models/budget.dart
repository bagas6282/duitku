import 'transaction.dart';

/// Monthly spending cap for one category.
///
/// [monthKey] pins the budget to a specific month (`yyyy-MM`) so history stays
/// intact when next month's limits differ.
class Budget {
  const Budget({
    this.id,
    required this.categoryId,
    required this.limitAmount,
    required this.monthKey,
  });

  final int? id;
  final int categoryId;
  final num limitAmount;

  /// Format: `2026-09`.
  final String monthKey;

  Budget copyWith({
    int? id,
    int? categoryId,
    num? limitAmount,
    String? monthKey,
  }) {
    return Budget(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      limitAmount: limitAmount ?? this.limitAmount,
      monthKey: monthKey ?? this.monthKey,
    );
  }

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'category_id': categoryId,
        'limit_amount': limitAmount,
        'month_key': monthKey,
      };

  static Budget fromMap(Map<String, Object?> m) => Budget(
        id: m['id']! as int,
        categoryId: m['category_id']! as int,
        limitAmount: m['limit_amount']! as num,
        monthKey: m['month_key']! as String,
      );
}

/// A savings goal: "laptop fund, Rp 7.000.000, by March".
class SavingsGoal {
  const SavingsGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.savedAmount,
    required this.colorIndex,
    this.deadline,
    this.done = false,
  });

  final int id;
  final String name;
  final num targetAmount;
  final num savedAmount;
  final int colorIndex;
  final DateTime? deadline;
  final bool done;

  double get ratio {
    if (targetAmount <= 0) return 0;
    return (savedAmount / targetAmount).clamp(0.0, 1.0);
  }

  num get remaining => (targetAmount - savedAmount).clamp(0, targetAmount);

  bool get isComplete => savedAmount >= targetAmount;

  /// Months left at the current pace, or null when no deadline is set.
  int? monthsToDeadline() {
    if (deadline == null) return null;
    final now = DateTime.now();
    final months = (deadline!.year - now.year) * 12 + (deadline!.month - now.month);
    return months;
  }

  /// How much must be set aside each month to hit the deadline.
  num? requiredMonthly() {
    final months = monthsToDeadline();
    if (months == null || months <= 0) return null;
    return remaining / months;
  }

  SavingsGoal copyWith({
    int? id,
    String? name,
    num? targetAmount,
    num? savedAmount,
    int? colorIndex,
    DateTime? deadline,
    bool? done,
  }) {
    return SavingsGoal(
      id: id ?? this.id,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      savedAmount: savedAmount ?? this.savedAmount,
      colorIndex: colorIndex ?? this.colorIndex,
      deadline: deadline ?? this.deadline,
      done: done ?? this.done,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'target_amount': targetAmount,
        'saved_amount': savedAmount,
        'color_index': colorIndex,
        'deadline': deadline?.millisecondsSinceEpoch,
        'done': done ? 1 : 0,
      };

  static SavingsGoal fromMap(Map<String, Object?> m) => SavingsGoal(
        id: m['id']! as int,
        name: m['name']! as String,
        targetAmount: m['target_amount']! as num,
        savedAmount: (m['saved_amount'] ?? 0) as num,
        colorIndex: (m['color_index'] ?? 0) as int,
        deadline: m['deadline'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['deadline']! as int),
        done: (m['done'] ?? 0) == 1,
      );
}

/// A template that spawns transactions on a schedule.
///
/// [dayOfMonth] drives monthly rules; [weekday] drives weekly ones. Only one
/// of them is read depending on [frequency].
class RecurringRule {
  const RecurringRule({
    required this.id,
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.walletId,
    required this.frequency,
    required this.nextRunAt,
    this.dayOfMonth = 1,
    this.weekday = 1,
    this.note = '',
    this.active = true,
  });

  final int id;
  final TxType type;
  final num amount;
  final int categoryId;
  final int walletId;
  final RecurFreq frequency;
  final DateTime nextRunAt;
  final int dayOfMonth;
  final int weekday;
  final String note;
  final bool active;

  RecurringRule copyWith({
    int? id,
    TxType? type,
    num? amount,
    int? categoryId,
    int? walletId,
    RecurFreq? frequency,
    DateTime? nextRunAt,
    int? dayOfMonth,
    int? weekday,
    String? note,
    bool? active,
  }) {
    return RecurringRule(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      walletId: walletId ?? this.walletId,
      frequency: frequency ?? this.frequency,
      nextRunAt: nextRunAt ?? this.nextRunAt,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      weekday: weekday ?? this.weekday,
      note: note ?? this.note,
      active: active ?? this.active,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'type': type.name,
        'amount': amount,
        'category_id': categoryId,
        'wallet_id': walletId,
        'frequency': frequency.name,
        'next_run_at': nextRunAt.millisecondsSinceEpoch,
        'day_of_month': dayOfMonth,
        'weekday': weekday,
        'note': note,
        'active': active ? 1 : 0,
      };

  static RecurringRule fromMap(Map<String, Object?> m) => RecurringRule(
        id: m['id']! as int,
        type: TxType.values.firstWhere(
          (t) => t.name == m['type'],
          orElse: () => TxType.expense,
        ),
        amount: m['amount']! as num,
        categoryId: (m['category_id'] ?? 0) as int,
        walletId: m['wallet_id']! as int,
        frequency: RecurFreq.values.firstWhere(
          (f) => f.name == m['frequency'],
          orElse: () => RecurFreq.monthly,
        ),
        nextRunAt:
            DateTime.fromMillisecondsSinceEpoch(m['next_run_at']! as int),
        dayOfMonth: (m['day_of_month'] ?? 1) as int,
        weekday: (m['weekday'] ?? 1) as int,
        note: (m['note'] ?? '') as String,
        active: (m['active'] ?? 1) == 1,
      );
}

enum RecurFreq { weekly, monthly }
