import 'package:accountant/features/budgets/data/budget.dart';
import 'package:accountant/features/scheduled/data/scheduled_payment.dart';
import 'package:accountant/features/scheduled/domain/scheduled_logic.dart';
import 'package:accountant/features/transactions/data/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('nextDueDate', () {
    test('once returns null', () {
      expect(nextDueDate('2026-10-14', ScheduleRepeat.once), isNull);
    });

    test('daily / weekly / monthly advance', () {
      expect(nextDueDate('2026-10-14', ScheduleRepeat.daily), '2026-10-15');
      expect(nextDueDate('2026-10-14', ScheduleRepeat.weekly), '2026-10-21');
      expect(nextDueDate('2026-10-14', ScheduleRepeat.monthly), '2026-11-14');
    });

    test('monthly clamps end of month', () {
      expect(nextDueDate('2026-01-31', ScheduleRepeat.monthly), '2026-02-28');
    });
  });

  group('occurrencesInCycle', () {
    test('counts monthly dues remaining in cycle', () {
      final n = occurrencesInCycle(
        dueDate: '2026-10-01',
        repeat: ScheduleRepeat.monthly,
        cycleStart: '2026-10-01',
        cycleEnd: '2026-10-31',
      );
      expect(n, 1);
    });

    test('counts weekly dues in a month window', () {
      final n = occurrencesInCycle(
        dueDate: '2026-10-01',
        repeat: ScheduleRepeat.weekly,
        cycleStart: '2026-10-01',
        cycleEnd: '2026-10-31',
      );
      expect(n, 5); // 1,8,15,22,29
    });
  });

  group('checkBudgetExceed', () {
    final budget = Budget(
      id: '1',
      category: 'Food',
      limit: 1000,
      createdAt: '2026-01-01T00:00:00.000Z',
    );

    test('blocks when projected over limit', () {
      final result = checkBudgetExceed(
        category: 'Food',
        amount: 600,
        dueDate: '2026-10-01',
        repeat: ScheduleRepeat.weekly,
        budgets: [budget],
        transactions: const [],
        cycleStartDay: 1,
        now: DateTime(2026, 10, 5),
      );
      expect(result.occurrences, greaterThan(1));
      expect(result.exceeds, isTrue);
    });

    test('allows when under limit', () {
      final result = checkBudgetExceed(
        category: 'Food',
        amount: 100,
        dueDate: '2026-10-20',
        repeat: ScheduleRepeat.once,
        budgets: [budget],
        transactions: [
          MoneyTransaction(
            id: 't1',
            title: 'Lunch',
            amount: 200,
            type: TransactionType.expense,
            category: 'Food',
            date: '2026-10-05',
            createdAt: '2026-10-05T00:00:00.000Z',
          ),
        ],
        cycleStartDay: 1,
        now: DateTime(2026, 10, 5),
      );
      expect(result.exceeds, isFalse);
      expect(result.spent, 200);
      expect(result.projected, 300);
    });
  });
}
