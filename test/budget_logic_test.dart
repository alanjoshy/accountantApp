// Pure budget cycle / window tests.

import 'package:accountant/features/activity/domain/cycle.dart';
import 'package:accountant/features/budgets/data/budget.dart';
import 'package:accountant/features/budgets/data/next_cycle_budget.dart';
import 'package:accountant/features/budgets/domain/budget_cycle.dart';
import 'package:accountant/features/budgets/domain/budget_logic.dart';
import 'package:accountant/features/settings/data/app_settings.dart';
import 'package:accountant/features/transactions/data/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

Budget _b({
  required String id,
  required String category,
  required double limit,
  String? start,
  String? end,
}) {
  return Budget(
    id: id,
    category: category,
    limit: limit,
    startDate: start,
    endDate: end,
    createdAt: '2026-01-01T00:00:00.000Z',
  );
}

MoneyTransaction _tx({
  required String category,
  required double amount,
  required String date,
}) {
  return MoneyTransaction(
    id: 't-$category-$date',
    title: category,
    amount: amount,
    type: TransactionType.expense,
    category: category,
    date: date,
    createdAt: date,
  );
}

void main() {
  test('listedBudgetsForWindow includes overlapping custom ranges', () {
    final bounds = (start: '2026-08-05', end: '2026-09-04');
    final rows = [
      _b(id: '1', category: 'Food', limit: 100, start: '2026-08-05', end: '2026-09-04'),
      _b(id: '2', category: 'Trip', limit: 50, start: '2026-08-01', end: '2026-08-31'),
      _b(id: '3', category: 'Old', limit: 10, start: '2026-06-01', end: '2026-06-30'),
      _b(id: '4', category: 'Legacy', limit: 20),
    ];
    final listed = listedBudgetsForWindow(rows, bounds, includeUndated: true);
    expect(listed.map((b) => b.id), containsAll(['1', '2', '4']));
    expect(listed.map((b) => b.id), isNot(contains('3')));
  });

  test('spentForBudget uses custom window', () {
    final budget = _b(
      id: '1',
      category: 'Food',
      limit: 1000,
      start: '2026-08-05',
      end: '2026-09-04',
    );
    final txs = [
      _tx(category: 'Food', amount: 100, date: '2026-08-10'),
      _tx(category: 'Food', amount: 50, date: '2026-07-01'),
      _tx(category: 'Travel', amount: 20, date: '2026-08-10'),
    ];
    expect(spentForBudget(budget, txs), 100);
  });

  test('spentInCalendarMonth sums prior calendar month', () {
    final txs = [
      _tx(category: 'Food', amount: 40, date: '2026-09-10'),
      _tx(category: 'Food', amount: 25, date: '2026-09-20'),
      _tx(category: 'Food', amount: 10, date: '2026-08-15'),
      _tx(category: 'Travel', amount: 5, date: '2026-09-12'),
    ];
    expect(spentInCalendarMonth('Food', txs, 2026, 8), 65);
    expect(spentInCalendarMonth('Food', txs, 2026, 7), 10);
    final prev = previousCalendarMonth(DateTime(2026, 10, 12));
    expect(prev.year, 2026);
    expect(prev.monthIndex, 8);
    expect(prev.label, 'Sep 2026');
  });

  test('nextCycleDisplayBudgets overlays draft when no next rows', () {
    final current = (start: '2026-08-05', end: '2026-09-04');
    final next = (start: '2026-09-05', end: '2026-10-04');
    final cycleRows = [
      _b(id: '1', category: 'Food', limit: 1000, start: current.start, end: current.end),
    ];
    final draft = NextCycleBudget(
      cycleStart: next.start,
      monthlyIncome: 8000,
      limits: const {'1': 1200},
      preparedAt: '2026-08-20T00:00:00.000Z',
    );
    final view = nextCycleDisplayBudgets([], cycleRows, current, next, draft);
    expect(view.isPreview, isTrue);
    expect(view.budgets.single.limit, 1200);
    expect(view.budgets.single.startDate, next.start);
  });

  test('activateNextCycleIfDue copies previous rows into current', () {
    final ref = DateTime(2026, 9, 6);
    final previous = getPreviousCycleDayBounds(5, ref);
    final current = getCurrentCycleDayBounds(5, ref);
    final budgets = [
      _b(
        id: 'old',
        category: 'Food',
        limit: 500,
        start: previous.start,
        end: previous.end,
      ),
    ];
    final draft = NextCycleBudget(
      cycleStart: current.start,
      monthlyIncome: 9000,
      limits: const {'old': 700},
      preparedAt: '2026-09-01T00:00:00.000Z',
    );
    final result = activateNextCycleIfDue(
      settings: AppSettings(
        monthlyIncome: 8000,
        cycleStartDay: 5,
        nextCycleBudget: draft,
      ),
      budgets: budgets,
      now: ref,
    );
    expect(result.activated, isTrue);
    expect(result.settings.monthlyIncome, 9000);
    expect(result.settings.nextCycleBudget, isNull);
    final currentRows = [
      for (final b in result.budgets) if (matchesBounds(b, current)) b,
    ];
    expect(currentRows, isNotEmpty);
    expect(currentRows.single.limit, 700);
    expect(currentRows.single.category, 'Food');
  });

  test('remainingToAllocate clamps at zero', () {
    final budgets = [
      _b(id: '1', category: 'Food', limit: 6000),
      _b(id: '2', category: 'Rent', limit: 5000),
    ];
    expect(remainingToAllocate(10000, budgets), 0);
    expect(totalAllocated(budgets), 11000);
  });

  test('formatBoundsLabel is readable', () {
    expect(
      formatBoundsLabel((start: '2026-08-05', end: '2026-09-04')),
      contains('2026'),
    );
  });
}
