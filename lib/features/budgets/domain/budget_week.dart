// Calendar-week budget balance (web budget-week.ts).

import '../../home/domain/home_logic.dart';
import '../../transactions/data/transaction.dart';
import 'budget_logic.dart';

class CalendarWeek {
  const CalendarWeek({
    required this.index,
    required this.startDay,
    required this.endDay,
    required this.dayCount,
    required this.startKey,
    required this.endKey,
    required this.label,
  });

  final int index;
  final int startDay;
  final int endDay;
  final int dayCount;
  final String startKey;
  final String endKey;
  final String label;
}

String dayKeyLocal(int year, int monthIndex, int day) {
  final m = (monthIndex + 1).toString().padLeft(2, '0');
  final d = day.toString().padLeft(2, '0');
  return '$year-$m-$d';
}

int mondayIndex(DateTime date) => (date.weekday + 6) % 7;
// DateTime.weekday: Mon=1 … Sun=7 → Mon=0 … Sun=6

/// Calendar weeks (Mon–Sun) clipped to the month.
List<CalendarWeek> calendarWeeksInMonth(int year, int monthIndex) {
  final daysInMonth = DateTime(year, monthIndex + 2, 0).day;
  final weeks = <CalendarWeek>[];
  var day = 1;
  var index = 0;
  while (day <= daysInMonth) {
    final startDay = day;
    final pad = mondayIndex(DateTime(year, monthIndex + 1, startDay));
    final endDay = (startDay + (6 - pad)).clamp(startDay, daysInMonth);
    final dayCount = endDay - startDay + 1;
    weeks.add(
      CalendarWeek(
        index: index,
        startDay: startDay,
        endDay: endDay,
        dayCount: dayCount,
        startKey: dayKeyLocal(year, monthIndex, startDay),
        endKey: dayKeyLocal(year, monthIndex, endDay),
        label: 'W${index + 1}',
      ),
    );
    index += 1;
    day = endDay + 1;
  }
  return weeks;
}

CalendarWeek currentWeekInMonth([DateTime? now]) {
  final ref = now ?? DateTime.now();
  final year = ref.year;
  final monthIndex = ref.month - 1;
  final todayDay = ref.day;
  final weeks = calendarWeeksInMonth(year, monthIndex);
  for (final w in weeks) {
    if (todayDay >= w.startDay && todayDay <= w.endDay) return w;
  }
  return weeks.first;
}

double spentInDateRange(
  String category,
  List<MoneyTransaction> transactions,
  String startKey,
  String endKey,
) {
  var sum = 0.0;
  for (final t in transactions) {
    if (t.type != TransactionType.expense || t.category != category) continue;
    final key = transactionDayKey(t.date);
    if (key.compareTo(startKey) < 0 || key.compareTo(endKey) > 0) continue;
    sum += t.amount;
  }
  return sum;
}

String weekRangeLabel(CalendarWeek week, [DateTime? now]) {
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
  final ref = now ?? DateTime.now();
  final month = months[ref.month - 1];
  return '${week.startDay}–${week.endDay} $month';
}

/// Monthly budget split by days in the current week; spent = expenses that week.
List<BudgetBalanceRow> buildWeeklyBudgetBalanceRows(
  List<BudgetBalanceRow> monthlyRows,
  List<MoneyTransaction> transactions, [
  DateTime? now,
]) {
  final ref = now ?? DateTime.now();
  final week = currentWeekInMonth(ref);
  final daysInMonth = DateTime(ref.year, ref.month + 1, 0).day;

  return [
    for (final r in monthlyRows)
      BudgetBalanceRow(
        id: r.id,
        category: r.category,
        limit: daysInMonth > 0 ? (r.limit * week.dayCount) / daysInMonth : 0,
        spent: spentInDateRange(
          r.category,
          transactions,
          week.startKey,
          week.endKey,
        ),
      ),
  ];
}
