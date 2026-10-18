import 'package:accountant/features/accounts/domain/payments.dart';
import 'package:accountant/features/debts/data/debt.dart';
import 'package:accountant/features/reminders/domain/reminder_engine.dart';
import 'package:accountant/features/reminders/domain/reminder_item.dart';
import 'package:accountant/features/scheduled/data/scheduled_payment.dart';
import 'package:accountant/features/settings/data/app_settings.dart';
import 'package:accountant/features/transactions/data/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

MoneyTransaction _tx({
  required String id,
  required TransactionType type,
  required String date,
  double amount = 10,
}) {
  return MoneyTransaction(
    id: id,
    title: 'Test',
    type: type,
    amount: amount,
    category: 'Food',
    date: date,
    createdAt: '${date}T12:00:00.000Z',
  );
}

void main() {
  test('buildCurrentBudgetPlanTip when unplanned', () {
    final tip = buildCurrentBudgetPlanTip(
      budgets: const [],
      monthlyIncome: 0,
      cycleStartDay: 1,
      now: DateTime(2026, 10, 14),
    );
    expect(tip?.id, 'budget-current-unplanned');
  });

  test('buildDailyLogTip when no expense today', () {
    final tip = buildDailyLogTip(
      transactions: [
        _tx(id: '1', type: TransactionType.expense, date: '2026-10-13'),
      ],
      now: DateTime(2026, 10, 14, 15),
    );
    expect(tip?.id, 'daily-log');

    final logged = buildDailyLogTip(
      transactions: [
        _tx(id: '1', type: TransactionType.expense, date: '2026-10-14'),
      ],
      now: DateTime(2026, 10, 14, 15),
    );
    expect(logged, isNull);
  });

  test('evaluateActive includes budget, daily, debt, scheduled', () {
    final settings = const AppSettings(
      monthlyIncome: 0,
      debtReminderLeadDays: 3,
      scheduledReminderLeadDays: 5,
    );
    final now = DateTime(2026, 10, 14, 12);
    final items = ReminderEngine.evaluateActive(
      settings: settings,
      transactions: const [],
      budgets: const [],
      debts: [
        Debt(
          id: 'd1',
          personName: 'Alex',
          amount: 100,
          amountPaid: 0,
          lentDate: '2026-10-01',
          dueDate: '2026-10-16',
          kind: DebtKind.lend,
          status: DebtStatus.open,
          createdAt: '2026-10-01T00:00:00.000Z',
          updatedAt: '2026-10-01T00:00:00.000Z',
        ),
      ],
      scheduledPayments: [
        ScheduledPayment(
          id: 's1',
          title: 'Rent',
          amount: 15000,
          dueDate: '2026-10-17',
          category: 'Rent',
          status: ScheduleStatus.pending,
          repeat: ScheduleRepeat.once,
          accountId: 'a1',
          paymentMode: PaymentMode.upi,
          createdAt: '2026-10-01T00:00:00.000Z',
          updatedAt: '2026-10-01T00:00:00.000Z',
        ),
      ],
      accounts: const [],
      formatMoney: (v) => '₹$v',
      now: now,
    );

    expect(items.any((i) => i.id == 'budget-current-unplanned'), isTrue);
    expect(items.any((i) => i.id == 'daily-log'), isTrue);
    expect(items.any((i) => i.id == 'debt-d1'), isTrue);
    expect(items.any((i) => i.id == 'sched-s1'), isTrue);
  });

  test('evaluateSchedules daily log when notifications on', () {
    final settings = const AppSettings(
      notificationsEnabled: true,
      dailyLogReminderEnabled: true,
      dailyLogReminderHour: 20,
      dailyLogReminderMinute: 0,
    );
    final schedules = ReminderEngine.evaluateSchedules(
      settings: settings,
      transactions: const [],
      budgets: const [],
      debts: const [],
      scheduledPayments: const [],
      formatMoney: (v) => '₹$v',
      now: DateTime(2026, 10, 14, 10),
    );
    expect(schedules.any((s) => s.id.startsWith('notify-daily-log-')), isTrue);
    expect(
      schedules.firstWhere((s) => s.id.startsWith('notify-daily-log-')).notifyAt,
      DateTime(2026, 10, 14, 20),
    );
  });

  test('stableNotificationId is stable and non-zero', () {
    expect(stableNotificationId('debt-1'), stableNotificationId('debt-1'));
    expect(stableNotificationId('debt-1'), isNot(0));
  });
}
