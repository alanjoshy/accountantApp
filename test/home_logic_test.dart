import 'package:flutter_test/flutter_test.dart';

import 'package:accountant/features/budgets/data/budget.dart';
import 'package:accountant/features/budgets/domain/budget_logic.dart';
import 'package:accountant/features/home/domain/home_logic.dart';
import 'package:accountant/features/transactions/data/transaction.dart';

MoneyTransaction _tx({
  required String id,
  required TransactionType type,
  required double amount,
  required String date,
  String category = 'Food',
}) {
  return MoneyTransaction(
    id: id,
    title: id,
    amount: amount,
    type: type,
    category: category,
    date: date,
    createdAt: date,
  );
}

void main() {
  test('computePaymentStreak counts consecutive payment days', () {
    final now = DateTime(2026, 10, 13);
    final txs = [
      _tx(id: '1', type: TransactionType.expense, amount: 10, date: '2026-10-13'),
      _tx(id: '2', type: TransactionType.income, amount: 5, date: '2026-10-12'),
      _tx(id: '3', type: TransactionType.expense, amount: 3, date: '2026-10-11'),
      _tx(id: '4', type: TransactionType.expense, amount: 3, date: '2026-10-09'),
    ];
    expect(computePaymentStreak(txs, now), 3);
  });

  test('computePaymentStreak allows yesterday start', () {
    final now = DateTime(2026, 10, 13);
    final txs = [
      _tx(id: '1', type: TransactionType.expense, amount: 10, date: '2026-10-12'),
      _tx(id: '2', type: TransactionType.expense, amount: 5, date: '2026-10-11'),
    ];
    expect(computePaymentStreak(txs, now), 2);
  });

  test('cycleTotals sums income and expense in cycle window', () {
    final now = DateTime(2026, 10, 13);
    final txs = [
      _tx(id: '1', type: TransactionType.income, amount: 1000, date: '2026-10-05'),
      _tx(id: '2', type: TransactionType.expense, amount: 250, date: '2026-10-10'),
      _tx(id: '3', type: TransactionType.expense, amount: 50, date: '2026-09-01'),
    ];
    final totals = cycleTotals(txs, 1, now);
    expect(totals.income, 1000);
    expect(totals.expense, 250);
    expect(totals.balance, 750);
  });

  test('homeCardTotals uses logged cycle income and expense', () {
    final now = DateTime(2026, 10, 13);
    final txs = [
      _tx(id: '1', type: TransactionType.income, amount: 1000, date: '2026-10-05'),
      _tx(id: '2', type: TransactionType.expense, amount: 250, date: '2026-10-10'),
    ];
    final totals = homeCardTotals(
      transactions: txs,
      cycleStartDay: 1,
      now: now,
    );
    expect(totals.income, 1000);
    expect(totals.expense, 250);
    expect(totals.balance, 750);
  });

  test('buildMonthPulseSnapshot heats days from expenses', () {
    final now = DateTime(2026, 10, 13);
    final budgets = [
      Budget(
        id: 'b1',
        category: 'Food',
        limit: 1000,
        period: 'monthly',
        createdAt: '2026-10-01T00:00:00.000Z',
        color: '#3b82f6',
      ),
    ];
    final txs = [
      _tx(
        id: '1',
        type: TransactionType.expense,
        amount: 200,
        date: '2026-10-05',
        category: 'Food',
      ),
      _tx(
        id: '2',
        type: TransactionType.income,
        amount: 500,
        date: '2026-10-08',
      ),
    ];
    final snap = buildMonthPulseSnapshot(
      transactions: txs,
      budgets: budgets,
      cycleStartDay: 1,
      monthlyIncome: 5000,
      viewYear: 2026,
      viewMonthIndex: 9,
      now: now,
    );
    expect(snap.activeDays, 2);
    expect(snap.story.topSpend, 200);
    expect(snap.story.topIncome, 500);
    expect(snap.categories, isNotEmpty);
    expect(snap.categories.first.spent, 200);
    expect(dailySpendHeatLevel(200, 1000, 31), greaterThan(0));
  });
}
