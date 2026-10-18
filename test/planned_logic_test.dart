import 'package:flutter_test/flutter_test.dart';

import 'package:accountant/features/activity/domain/cycle.dart';
import 'package:accountant/features/budgets/data/budget.dart';
import 'package:accountant/features/planned/data/planned_reserve.dart';
import 'package:accountant/features/planned/domain/planned_logic.dart';

PlannedReserve _r({
  required String id,
  required String dueDate,
  String category = 'Transport',
  double amount = 2100,
  String? applied,
}) {
  return PlannedReserve(
    id: id,
    title: id,
    amount: amount,
    category: category,
    dueDate: dueDate,
    appliedCycleStart: applied,
    createdAt: dueDate,
    updatedAt: dueDate,
  );
}

Budget _b(String id, String category, double limit) {
  return Budget(
    id: id,
    category: category,
    limit: limit,
    period: 'monthly',
    createdAt: '2026-01-01T00:00:00.000Z',
    color: '#3b82f6',
  );
}

void main() {
  test('reservesForNextCycle picks dues in upcoming cash-flow cycle', () {
    // Cycle starts on 1st → on 2026-10-28, next cycle is Nov 1–30.
    final now = DateTime(2026, 10, 28);
    final items = [
      _r(id: 'ins', dueDate: '2026-11-15'),
      _r(id: 'old', dueDate: '2026-10-10'),
      _r(id: 'later', dueDate: '2026-12-05'),
    ];
    final next = reservesForNextCycle(items, 1, now);
    expect(next.map((r) => r.id), ['ins']);
  });

  test('planning-window tip appears only in 5-day lead', () {
    final items = [_r(id: 'ins', dueDate: '2026-11-15')];
    // 3 days before Nov 1 → in window.
    final tips = buildPlannedReserveReminderTips(
      items,
      cycleStartDay: 1,
      formatMoney: (v) => '₹${v.toInt()}',
      now: DateTime(2026, 10, 29),
    );
    expect(tips, isNotEmpty);

    // Mid-month → not in planning window.
    final quiet = buildPlannedReserveReminderTips(
      items,
      cycleStartDay: 1,
      formatMoney: (v) => '₹${v.toInt()}',
      now: DateTime(2026, 10, 15),
    );
    expect(quiet, isEmpty);
  });

  test('applyReserveTotalsToLimits adds by category', () {
    final budgets = [
      _b('t', 'Transport', 5000),
      _b('f', 'Food', 3000),
    ];
    final next = applyReserveTotalsToLimits(
      limits: {'t': 5000, 'f': 3000},
      budgets: budgets,
      reserves: [
        _r(id: '1', dueDate: '2026-12-01', amount: 2100),
        _r(id: '2', dueDate: '2026-12-02', amount: 400, category: 'Food'),
      ],
    );
    expect(next['t'], 7100);
    expect(next['f'], 3400);
  });

  test('unappliedReservesForCycle skips already applied', () {
    final bounds = getNextCycleDayBounds(1, DateTime(2026, 10, 28));
    final items = [
      _r(id: 'a', dueDate: '2026-11-10'),
      _r(id: 'b', dueDate: '2026-11-12', applied: bounds.start),
    ];
    final open = unappliedReservesForCycle(
      items,
      cycleStart: bounds.start,
      cycleEnd: bounds.end,
    );
    expect(open.map((r) => r.id), ['a']);
  });

  test('isNextCyclePlanningWindow matches lead days', () {
    expect(isNextCyclePlanningWindow(1, DateTime(2026, 10, 28)), isTrue);
    expect(isNextCyclePlanningWindow(1, DateTime(2026, 10, 10)), isFalse);
  });
}
