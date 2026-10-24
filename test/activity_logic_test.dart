// Pure activity filter / breakdown tests.

import 'package:flutter_test/flutter_test.dart';

import 'package:accountant/features/activity/domain/activity_logic.dart';
import 'package:accountant/features/activity/domain/cycle.dart';
import 'package:accountant/features/transactions/data/transaction.dart';

MoneyTransaction _tx({
  required String id,
  required TransactionType type,
  required double amount,
  required String date,
  String category = 'Food',
  String title = 'Item',
  List<String> tags = const [],
}) {
  return MoneyTransaction(
    id: id,
    title: title,
    amount: amount,
    type: type,
    category: category,
    date: date,
    createdAt: date,
    tags: tags,
  );
}

void main() {
  final now = DateTime(2026, 10, 12, 12);

  test('filters out transfers and respects type/period', () {
    final list = [
      _tx(
        id: '1',
        type: TransactionType.expense,
        amount: 100,
        date: '2026-10-11T10:00:00.000',
      ),
      _tx(
        id: '2',
        type: TransactionType.income,
        amount: 500,
        date: '2026-10-10T10:00:00.000',
        category: 'Salary',
      ),
      _tx(
        id: '3',
        type: TransactionType.transfer,
        amount: 50,
        date: '2026-10-11T10:00:00.000',
      ),
      _tx(
        id: '4',
        type: TransactionType.expense,
        amount: 20,
        date: '2026-08-01T10:00:00.000',
      ),
    ];

    final filtered = filterActivityTransactions(
      list,
      type: ActivityTypeFilter.expense,
      period: ActivityPeriodFilter.d30,
      now: now,
    );

    expect(filtered.map((t) => t.id), ['1']);
  });

  test('buildExpenseCategoryBreakdown and sumByType', () {
    final list = [
      _tx(
        id: '1',
        type: TransactionType.expense,
        amount: 30,
        date: '2026-10-01',
      ),
      _tx(
        id: '2',
        type: TransactionType.expense,
        amount: 70,
        date: '2026-10-02',
        category: 'Rent',
      ),
      _tx(
        id: '3',
        type: TransactionType.income,
        amount: 100,
        date: '2026-10-02',
        category: 'Salary',
      ),
    ];
    final rows = buildExpenseCategoryBreakdown(list);
    expect(rows.first.label, 'Rent');
    expect(rows.first.share, closeTo(0.7, 0.001));

    final totals = sumByType(list);
    expect(totals.income, 100);
    expect(totals.expense, 100);
  });

  test('totalBudgetPool prefers budget limits', () {
    expect(totalBudgetPool([1000, 500], 8000), 1500);
    expect(totalBudgetPool(const [], 8000), 8000);
    expect(totalBudgetPool(const [], 0), 0);
  });

  test('cycleDayCount is at least 1', () {
    expect(cycleDayCount(1, DateTime(2026, 10, 15)), greaterThanOrEqualTo(28));
    expect(clampCycleStartDay(0), 1);
    expect(clampCycleStartDay(40), 28);
  });

  test('groupTransactionsByDay skips transfers and sorts newest first', () {
    final groups = groupTransactionsByDay([
      _tx(
        id: 'old',
        type: TransactionType.expense,
        amount: 10,
        date: '2026-10-01T10:00:00.000',
      ),
      _tx(
        id: 'new',
        type: TransactionType.income,
        amount: 20,
        date: '2026-10-11T10:00:00.000',
        category: 'Salary',
      ),
      _tx(
        id: 'xfer',
        type: TransactionType.transfer,
        amount: 5,
        date: '2026-10-11T12:00:00.000',
      ),
      _tx(
        id: 'same-day',
        type: TransactionType.expense,
        amount: 7,
        date: '2026-10-11T18:00:00.000',
      ),
    ]);
    expect(groups.map((g) => g.key), ['2026-10-11', '2026-10-01']);
    expect(groups.first.credit, 20);
    expect(groups.first.debit, 7);
    expect(groups.first.items.map((t) => t.id), ['new', 'same-day']);
  });

  test('paginateDayGroups keeps whole days and reports hasMore', () {
    final groups = [
      for (var d = 10; d >= 1; d--)
        DayGroup(
          key: '2026-10-${d.toString().padLeft(2, '0')}',
          heading: 'Day $d',
          credit: 0,
          debit: 8,
          items: [
            _tx(
              id: 'd${d}a',
              type: TransactionType.expense,
              amount: 4,
              date: '2026-10-${d.toString().padLeft(2, '0')}T10:00:00.000',
            ),
            _tx(
              id: 'd${d}b',
              type: TransactionType.expense,
              amount: 4,
              date: '2026-10-${d.toString().padLeft(2, '0')}T11:00:00.000',
            ),
          ],
        ),
    ];

    final first = paginateDayGroups(groups, 5);
    expect(first.hasMore, isTrue);
    expect(first.totalCount, 20);
    expect(first.shownCount, 6);
    expect(first.groups.map((g) => g.key), [
      '2026-10-10',
      '2026-10-09',
      '2026-10-08',
    ]);

    final all = paginateDayGroups(groups, 40);
    expect(all.hasMore, isFalse);
    expect(all.groups, groups);

    final empty = paginateDayGroups(groups, 0);
    expect(empty.groups, isEmpty);
    expect(empty.totalCount, 20);
  });

  test('buildDailySpendBars maps allowance like month-pulse category bars', () {
    final points = [
      const DailySpendPoint(
        key: '2026-10-01',
        label: 'Thu, Oct 1',
        shortLabel: 'Thu 1',
        amount: 20,
      ),
      const DailySpendPoint(
        key: '2026-10-02',
        label: 'Fri, Oct 2',
        shortLabel: 'Fri 2',
        amount: 150,
      ),
      const DailySpendPoint(
        key: '2026-10-03',
        label: 'Sat, Oct 3',
        shortLabel: 'Sat 3',
        amount: 0,
      ),
    ];

    final bars = buildDailySpendBars(points, dailyAllowance: 100);
    expect(bars, hasLength(3));
    expect(bars[0].over, isFalse);
    expect(bars[0].fillRatio, closeTo(0.2, 0.001));
    expect(bars[0].topLabel, '80');
    expect(bars[0].heatLevel, 1);

    expect(bars[1].over, isTrue);
    expect(bars[1].fillRatio, 1);
    expect(bars[1].topLabel, '+50');
    expect(bars[1].heatLevel, 4);

    expect(bars[2].fillRatio, 0);
    expect(bars[2].heatLevel, 0);
    expect(bars[2].topLabel, '100');
    expect(formatActivityBarAmount(1500), '1.5k');
  });

  test('Activity month filter uses cash-flow cycle start day', () {
    final ref = DateTime(2026, 10, 12, 12);
    final range = getActivityPeriodRange(
      ActivityPeriodFilter.month,
      now: ref,
      cycleStartDay: 25,
    );
    expect(range, isNotNull);
    expect(range!.start, DateTime(2026, 9, 25));
    expect(range.end.year, 2026);
    expect(range.end.month, 10);
    expect(range.end.day, 24);

    final list = [
      _tx(
        id: 'in',
        type: TransactionType.expense,
        amount: 10,
        date: '2026-09-26T10:00:00.000',
      ),
      _tx(
        id: 'out',
        type: TransactionType.expense,
        amount: 10,
        date: '2026-09-20T10:00:00.000',
      ),
    ];
    final filtered = filterActivityTransactions(
      list,
      type: ActivityTypeFilter.all,
      period: ActivityPeriodFilter.month,
      now: ref,
      cycleStartDay: 25,
    );
    expect(filtered.map((t) => t.id), ['in']);
  });
}
