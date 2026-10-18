import 'package:accountant/features/budgets/domain/budget_logic.dart';
import 'package:accountant/features/budgets/domain/budget_week.dart';
import 'package:accountant/features/transactions/data/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('currentWeekInMonth clips Mon–Sun to calendar month', () {
    final week = currentWeekInMonth(DateTime(2026, 10, 15));
    expect(week.startDay, lessThanOrEqualTo(15));
    expect(week.endDay, greaterThanOrEqualTo(15));
    expect(week.dayCount, inInclusiveRange(1, 7));
  });

  test('buildWeeklyBudgetBalanceRows scales limit and spends in week', () {
    final monthly = [
      const BudgetBalanceRow(
        id: '1',
        category: 'Food',
        limit: 3100,
        spent: 0,
      ),
    ];
    final now = DateTime(2026, 10, 15); // mid-month
    final week = currentWeekInMonth(now);
    final txs = [
      MoneyTransaction(
        id: 't1',
        title: 'Lunch',
        amount: 100,
        type: TransactionType.expense,
        category: 'Food',
        date: week.startKey,
        createdAt: '${week.startKey}T12:00:00.000Z',
      ),
      MoneyTransaction(
        id: 't2',
        title: 'Old',
        amount: 999,
        type: TransactionType.expense,
        category: 'Food',
        date: '2026-09-01',
        createdAt: '2026-09-01T12:00:00.000Z',
      ),
    ];
    final rows = buildWeeklyBudgetBalanceRows(monthly, txs, now);
    expect(rows.single.spent, 100);
    final daysInMonth = DateTime(2026, 11, 0).day;
    expect(
      rows.single.limit,
      closeTo(3100 * week.dayCount / daysInMonth, 0.01),
    );
  });
}
