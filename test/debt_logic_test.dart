// Pure debt helpers.

import 'package:accountant/features/debts/data/debt.dart';
import 'package:accountant/features/debts/domain/debt_logic.dart';
import 'package:flutter_test/flutter_test.dart';

Debt _d({
  required String id,
  required String person,
  required double amount,
  double paid = 0,
  DebtKind kind = DebtKind.lend,
  DebtStatus status = DebtStatus.open,
  String due = '2026-10-15',
  String lent = '2026-10-01',
}) {
  return Debt(
    id: id,
    personName: person,
    amount: amount,
    amountPaid: paid,
    lentDate: lent,
    dueDate: due,
    kind: kind,
    status: status,
    createdAt: '2026-10-01T00:00:00.000Z',
    updatedAt: '2026-10-01T00:00:00.000Z',
  );
}

void main() {
  test('debtRemaining clamps and ignores invalid paid', () {
    expect(debtRemaining(_d(id: '1', person: 'A', amount: 100, paid: 40)), 60);
    expect(debtRemaining(_d(id: '1', person: 'A', amount: 100, paid: 150)), 0);
    expect(debtPaid(_d(id: '1', person: 'A', amount: 100, paid: -5)), 0);
  });

  test('personNetBalances nets lend vs borrow', () {
    final nets = personNetBalances([
      _d(id: '1', person: 'Rahul', amount: 500, paid: 100),
      _d(
        id: '2',
        person: 'Rahul',
        amount: 200,
        kind: DebtKind.borrow,
      ),
      _d(id: '3', person: 'Priya', amount: 50),
    ]);
    final rahul = nets.firstWhere((p) => p.name == 'Rahul');
    expect(rahul.lendRemaining, 400);
    expect(rahul.borrowRemaining, 200);
    expect(rahul.net, 200);
  });

  test('buildDebtReminderTips only within window', () {
    final now = DateTime(2026, 10, 12);
    final tips = buildDebtReminderTips(
      [
        _d(id: 'soon', person: 'A', amount: 100, due: '2026-10-14'),
        _d(id: 'far', person: 'B', amount: 100, due: '2026-10-30'),
        _d(
          id: 'over',
          person: 'C',
          amount: 80,
          kind: DebtKind.borrow,
          due: '2026-10-10',
        ),
        _d(
          id: 'done',
          person: 'D',
          amount: 10,
          status: DebtStatus.collected,
          due: '2026-10-13',
        ),
      ],
      now: now,
      formatMoney: (v) => '₹${v.toStringAsFixed(0)}',
    );
    expect(tips.map((t) => t.id), containsAll(['debt-soon', 'debt-over']));
    expect(tips.map((t) => t.id), isNot(contains('debt-far')));
    expect(tips.map((t) => t.id), isNot(contains('debt-done')));
    expect(tips.first.id, 'debt-over');
  });

  test('daysUntilDue and todayKey', () {
    final now = DateTime(2026, 10, 12);
    expect(daysUntilDue('2026-10-12', now), 0);
    expect(daysUntilDue('2026-10-10', now), -2);
    expect(todayKey(now), '2026-10-12');
  });
}
