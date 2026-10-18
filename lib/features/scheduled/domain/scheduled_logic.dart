// Pure scheduled-payment helpers (web scheduled-payments.ts + exceed check).

import '../../activity/domain/cycle.dart';
import '../../budgets/data/budget.dart';
import '../../budgets/domain/budget_logic.dart';
import '../../home/presentation/data/static_remember_tips.dart';
import '../../transactions/data/transaction.dart';
import '../data/scheduled_payment.dart';

const scheduledReminderWindowDays = 5;

const scheduledCategories = <String>[
  'Investment',
  'EMI',
  'Rent',
  'Bills',
  'Subscription',
  'Insurance',
  'Savings',
  'Other',
];

class RepeatOption {
  const RepeatOption({
    required this.id,
    required this.label,
    required this.short,
  });

  final ScheduleRepeat id;
  final String label;
  final String short;
}

const repeatOptions = <RepeatOption>[
  RepeatOption(id: ScheduleRepeat.once, label: 'One time', short: 'Once'),
  RepeatOption(id: ScheduleRepeat.daily, label: 'Every day', short: 'Daily'),
  RepeatOption(id: ScheduleRepeat.weekly, label: 'Every week', short: 'Weekly'),
  RepeatOption(
    id: ScheduleRepeat.monthly,
    label: 'Every month',
    short: 'Monthly',
  ),
];

String scheduleTodayKey([DateTime? now]) => toCycleDayKey(now ?? DateTime.now());

bool isDueOrOverdue(String dueDate, [DateTime? now]) =>
    dueDate.compareTo(scheduleTodayKey(now)) <= 0;

String? nextDueDate(String dueDate, ScheduleRepeat repeat) {
  if (repeat == ScheduleRepeat.once) return null;
  final parts = dueDate.split('-');
  if (parts.length < 3) return null;
  final y = int.tryParse(parts[0]) ?? 1970;
  final m = int.tryParse(parts[1]) ?? 1;
  final d = int.tryParse(parts[2]) ?? 1;
  final base = DateTime(y, m, d);

  if (repeat == ScheduleRepeat.daily) {
    return toCycleDayKey(base.add(const Duration(days: 1)));
  }
  if (repeat == ScheduleRepeat.weekly) {
    return toCycleDayKey(base.add(const Duration(days: 7)));
  }

  final nextMonth = DateTime(y, m + 1, 1);
  final lastDay = DateTime(nextMonth.year, nextMonth.month + 1, 0).day;
  final clamped = d > lastDay ? lastDay : d;
  return toCycleDayKey(DateTime(nextMonth.year, nextMonth.month, clamped));
}

String repeatLabel(ScheduleRepeat repeat) {
  for (final o in repeatOptions) {
    if (o.id == repeat) return o.label;
  }
  return repeat.name;
}

List<String> budgetCategoryChoices(List<String> budgetCategories) {
  final names = <String>{
    for (final c in budgetCategories)
      if (c.trim().isNotEmpty) c.trim(),
  };
  if (names.isEmpty) return [...scheduledCategories];
  return names.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
}

/// Count dues from [dueDate] inclusive through [cycleEnd] inclusive.
int occurrencesInCycle({
  required String dueDate,
  required ScheduleRepeat repeat,
  required String cycleStart,
  required String cycleEnd,
}) {
  if (dueDate.compareTo(cycleEnd) > 0) return 0;
  var cursor = dueDate.compareTo(cycleStart) < 0 ? dueDate : dueDate;
  // Advance to first occurrence on/after cycle start.
  if (cursor.compareTo(cycleStart) < 0) {
    if (repeat == ScheduleRepeat.once) return 0;
    for (var i = 0; i < 4000; i++) {
      final next = nextDueDate(cursor, repeat);
      if (next == null) return 0;
      cursor = next;
      if (cursor.compareTo(cycleStart) >= 0) break;
    }
  }
  if (cursor.compareTo(cycleStart) < 0 || cursor.compareTo(cycleEnd) > 0) {
    return 0;
  }

  var count = 0;
  var day = cursor;
  for (var i = 0; i < 4000; i++) {
    if (day.compareTo(cycleEnd) > 0) break;
    if (day.compareTo(cycleStart) >= 0) count += 1;
    if (repeat == ScheduleRepeat.once) break;
    final next = nextDueDate(day, repeat);
    if (next == null) break;
    day = next;
  }
  return count;
}

class BudgetExceedResult {
  const BudgetExceedResult({
    required this.exceeds,
    required this.spent,
    required this.projected,
    required this.limit,
    required this.occurrences,
  });

  final bool exceeds;
  final double spent;
  final double projected;
  final double limit;
  final int occurrences;

  double get overBy => (projected - limit).clamp(0, double.infinity);
}

/// Whether scheduling [amount] × remaining dues would blow the category limit.
BudgetExceedResult checkBudgetExceed({
  required String category,
  required double amount,
  required String dueDate,
  required ScheduleRepeat repeat,
  required List<Budget> budgets,
  required List<MoneyTransaction> transactions,
  required int cycleStartDay,
  DateTime? now,
}) {
  final ref = now ?? DateTime.now();
  final bounds = getCurrentCycleDayBounds(cycleStartDay, ref);
  Budget? budget;
  for (final b in budgets) {
    if (b.category.trim().toLowerCase() == category.trim().toLowerCase()) {
      budget = b;
      break;
    }
  }
  final limit = budget?.limit ?? 0;
  final spent = budget == null
      ? 0.0
      : spentForBudget(
          budget,
          transactions,
          now: ref,
          cycleStartDay: cycleStartDay,
        );
  final occ = occurrencesInCycle(
    dueDate: dueDate,
    repeat: repeat,
    cycleStart: bounds.start,
    cycleEnd: bounds.end,
  );
  final projected = spent + amount * occ;
  final exceeds = limit > 0 && occ > 0 && projected > limit + 0.0001;
  return BudgetExceedResult(
    exceeds: exceeds,
    spent: spent,
    projected: projected,
    limit: limit,
    occurrences: occ,
  );
}

String formatDueHeading(String dueDate) {
  final parts = dueDate.split('-');
  if (parts.length < 3) return dueDate;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return dueDate;
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '$d ${months[m - 1]}';
}

List<StaticRememberTip> buildScheduledPaymentReminderTips(
  List<ScheduledPayment> payments, {
  required String Function(double) formatMoney,
  DateTime? now,
  int windowDays = scheduledReminderWindowDays,
}) {
  final tips = <StaticRememberTip>[];
  final ref = now ?? DateTime.now();
  final window = windowDays < 0 ? scheduledReminderWindowDays : windowDays;

  for (final payment in payments) {
    if (payment.status != ScheduleStatus.pending) continue;
    final days = _daysUntilDue(payment.dueDate, ref);
    if (days > window) continue;

    final tone = days < 0 || days <= 1
        ? RememberTone.warning
        : RememberTone.info;

    tips.add(
      StaticRememberTip(
        id: 'sched-${payment.id}',
        title: _scheduledSendTitle(days),
        body:
            '${payment.title} · ${formatMoney(payment.amount)}${payment.category.isNotEmpty ? ' from ${payment.category}' : ''} due ${formatDueHeading(payment.dueDate)}.',
        tone: tone,
        hrefLabel: 'Open scheduled',
      ),
    );
  }

  // Recently paid (last 2 days) — user asked completed payments in Remember.
  final today = scheduleTodayKey(ref);
  for (final payment in payments) {
    if (payment.status != ScheduleStatus.paid || payment.paidAt == null) {
      continue;
    }
    final paidDay = payment.paidAt!.length >= 10
        ? payment.paidAt!.substring(0, 10)
        : payment.dueDate;
    final age = _daysBetween(paidDay, today);
    if (age < 0 || age > 2) continue;
    tips.add(
      StaticRememberTip(
        id: 'sched-paid-${payment.id}',
        title: 'Payment completed',
        body:
            '${payment.title} · ${formatMoney(payment.amount)} marked paid${payment.category.isNotEmpty ? ' · ${payment.category}' : ''}.',
        tone: RememberTone.success,
        hrefLabel: 'Open scheduled',
      ),
    );
  }

  tips.sort((a, b) {
    final idA = a.id.replaceFirst(RegExp(r'^sched-(paid-)?'), '');
    final idB = b.id.replaceFirst(RegExp(r'^sched-(paid-)?'), '');
    final pA = payments.where((p) => p.id == idA).firstOrNull;
    final pB = payments.where((p) => p.id == idB).firstOrNull;
    if (pA == null || pB == null) return 0;
    return _daysUntilDue(pA.dueDate, ref) - _daysUntilDue(pB.dueDate, ref);
  });
  return tips;
}

int _daysUntilDue(String dueDate, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final parts = dueDate.split('-');
  if (parts.length < 3) return 0;
  final y = int.tryParse(parts[0]) ?? today.year;
  final m = int.tryParse(parts[1]) ?? 1;
  final d = int.tryParse(parts[2]) ?? 1;
  return DateTime(y, m, d).difference(today).inDays;
}

int _daysBetween(String fromKey, String toKey) {
  final a = fromKey.split('-');
  final b = toKey.split('-');
  if (a.length < 3 || b.length < 3) return 999;
  final from = DateTime(
    int.tryParse(a[0]) ?? 0,
    int.tryParse(a[1]) ?? 1,
    int.tryParse(a[2]) ?? 1,
  );
  final to = DateTime(
    int.tryParse(b[0]) ?? 0,
    int.tryParse(b[1]) ?? 1,
    int.tryParse(b[2]) ?? 1,
  );
  return to.difference(from).inDays;
}

String _scheduledSendTitle(int days) {
  if (days < 0) {
    final n = days.abs();
    return n == 1
        ? '1 day overdue — send money'
        : '$n days overdue — send money';
  }
  if (days == 0) return 'Send money today';
  if (days == 1) return '1 day left to send money';
  return '$days days left to send money';
}
