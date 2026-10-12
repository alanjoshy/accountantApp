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
      _tx(id: '1', type: TransactionType.expense, amount: 30, date: '2026-10-01'),
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
}
