// Home totals, streak, and month-pulse snapshots (web page + MonthActivityStreak).

import '../../activity/domain/cycle.dart';
import '../../budgets/data/budget.dart';
import '../../budgets/domain/budget_logic.dart';
import '../../transactions/data/transaction.dart';

String transactionDayKey(String dateIso) {
  if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(dateIso)) {
    return dateIso.substring(0, 10);
  }
  final d = DateTime.tryParse(dateIso)?.toLocal();
  if (d == null) return dateIso;
  return toCycleDayKey(d);
}

/// Consecutive days with at least one non-transfer payment (today or yesterday start).
int computePaymentStreak(
  List<MoneyTransaction> transactions, [
  DateTime? now,
]) {
  final active = <String>{
    for (final t in transactions)
      if (t.type != TransactionType.transfer) transactionDayKey(t.date),
  };
  var cursor = dateOnly(now ?? DateTime.now());
  if (!active.contains(toCycleDayKey(cursor))) {
    cursor = cursor.subtract(const Duration(days: 1));
    if (!active.contains(toCycleDayKey(cursor))) return 0;
  }

  var n = 0;
  while (active.contains(toCycleDayKey(cursor))) {
    n += 1;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return n;
}

class HomePeriodTotals {
  const HomePeriodTotals({required this.income, required this.expense});

  final double income;
  final double expense;

  double get balance => income - expense;
}

bool _inDayBounds(String dateIso, String start, String end) {
  final key = transactionDayKey(dateIso);
  return key.compareTo(start) >= 0 && key.compareTo(end) <= 0;
}

HomePeriodTotals totalsInDayBounds(
  List<MoneyTransaction> transactions,
  String start,
  String end,
) {
  var income = 0.0;
  var expense = 0.0;
  for (final t in transactions) {
    if (!_inDayBounds(t.date, start, end)) continue;
    if (t.type == TransactionType.income) {
      income += t.amount;
    } else if (t.type == TransactionType.expense) {
      expense += t.amount;
    }
  }
  return HomePeriodTotals(income: income, expense: expense);
}

/// Cash-flow cycle totals (web home default period = month/cycle).
HomePeriodTotals cycleTotals(
  List<MoneyTransaction> transactions,
  int cycleStartDay, [
  DateTime? now,
]) {
  final bounds = getCurrentCycleDayBounds(cycleStartDay, now);
  return totalsInDayBounds(transactions, bounds.start, bounds.end);
}

/// Home balance card Income / Expense tiles (web home period totals).
///
/// Uses logged cycle cash flow so adding a transaction updates the tiles.
/// Battery capacity still uses the Budgets monthly-income plan separately.
HomePeriodTotals homeCardTotals({
  required List<MoneyTransaction> transactions,
  required int cycleStartDay,
  DateTime? now,
}) {
  return cycleTotals(transactions, cycleStartDay, now);
}

/// Battery pool: monthly income plan, else logged cycle income, else budget sum.
double batteryCapacity({
  required double monthlyIncome,
  required Iterable<Budget> budgets,
  double loggedIncome = 0,
}) {
  if (monthlyIncome > 0) return monthlyIncome;
  if (loggedIncome > 0) return loggedIncome;
  final allocated = totalAllocated(budgets);
  return allocated > 0 ? allocated : 0;
}

class DayMoney {
  DayMoney({this.expense = 0, this.income = 0, this.count = 0});

  double expense;
  double income;
  int count;
}

class MonthPulseCategoryBar {
  const MonthPulseCategoryBar({
    required this.id,
    required this.label,
    required this.spent,
    required this.limit,
    required this.colorHex,
  });

  final String id;
  final String label;
  final double spent;
  final double limit;
  final String colorHex;
}

class MonthPulseStory {
  const MonthPulseStory({
    this.topSpendKey,
    this.topSpend = 0,
    this.topIncomeKey,
    this.topIncome = 0,
  });

  final String? topSpendKey;
  final double topSpend;
  final String? topIncomeKey;
  final double topIncome;
}

class MonthPulseSnapshot {
  const MonthPulseSnapshot({
    required this.year,
    required this.monthIndex,
    required this.monthLabel,
    required this.cycleHint,
    required this.categories,
    required this.heat,
    required this.activeDays,
    required this.daysInMonth,
    required this.story,
    required this.canGoPrev,
    required this.canGoNext,
    required this.paymentStreak,
  });

  final int year;
  final int monthIndex;
  final String monthLabel;
  final String cycleHint;
  final List<MonthPulseCategoryBar> categories;
  /// 6×7 grid; -1 = pad, 0 = empty day, 1–4 = spend intensity.
  final List<int> heat;
  final int activeDays;
  final int daysInMonth;
  final MonthPulseStory story;
  final bool canGoPrev;
  final bool canGoNext;
  final int paymentStreak;
}

const _monthNames = [
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

const _barColorHex = [
  '#3b82f6',
  '#22c55e',
  '#f59e0b',
  '#ef4444',
  '#a855f7',
  '#06b6d4',
  '#ec4899',
  '#84cc16',
  '#f97316',
  '#6366f1',
];

String formatPulseDayKey(String key) {
  final parts = key.split('-');
  if (parts.length < 3) return key;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null || m < 1 || m > 12) return key;
  return '$d ${_monthNames[m - 1]}';
}

Map<String, DayMoney> _byDayForMonth(
  List<MoneyTransaction> transactions,
  int year,
  int monthIndex,
) {
  final prefix =
      '$year-${(monthIndex + 1).toString().padLeft(2, '0')}';
  final map = <String, DayMoney>{};
  for (final t in transactions) {
    if (t.type == TransactionType.transfer) continue;
    final key = transactionDayKey(t.date);
    if (!key.startsWith(prefix)) continue;
    final cur = map.putIfAbsent(key, DayMoney.new);
    cur.count += 1;
    if (t.type == TransactionType.expense) {
      cur.expense += t.amount;
    } else if (t.type == TransactionType.income) {
      cur.income += t.amount;
    }
  }
  return map;
}

({int year, int monthIndex}) _earliestMonth(
  List<MoneyTransaction> transactions,
  int currentYear,
  int currentMonthIndex,
) {
  var min = currentYear * 12 + currentMonthIndex;
  for (final t in transactions) {
    final key = transactionDayKey(t.date);
    final parts = key.split('-');
    if (parts.length < 2) continue;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (y == null || m == null) continue;
    final mk = y * 12 + (m - 1);
    if (mk < min) min = mk;
  }
  final floor = currentYear * 12 + currentMonthIndex - 23;
  final clamped = min < floor ? floor : min;
  return (year: clamped ~/ 12, monthIndex: clamped % 12);
}

MonthPulseSnapshot buildMonthPulseSnapshot({
  required List<MoneyTransaction> transactions,
  required List<Budget> budgets,
  required int cycleStartDay,
  required double monthlyIncome,
  required int viewYear,
  required int viewMonthIndex,
  DateTime? now,
  List<BudgetBalanceRow>? cycleBalanceRows,
  int? paymentStreak,
}) {
  final ref = now ?? DateTime.now();
  final currentYear = ref.year;
  final currentMonth = ref.month - 1;
  final daysInMonth = DateTime(viewYear, viewMonthIndex + 2, 0).day;
  final firstWeekday = DateTime(viewYear, viewMonthIndex + 1, 1).weekday;
  final leading = firstWeekday - 1;
  final isCurrentMonth =
      viewYear == currentYear && viewMonthIndex == currentMonth;

  final byDay = _byDayForMonth(transactions, viewYear, viewMonthIndex);
  var maxExpense = 0.0;
  for (final v in byDay.values) {
    if (v.expense > maxExpense) maxExpense = v.expense;
  }

  var activeDays = 0;
  for (var d = 1; d <= daysInMonth; d++) {
    final key =
        '$viewYear-${(viewMonthIndex + 1).toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
    final v = byDay[key];
    if (v != null && v.count > 0) activeDays += 1;
  }

  String? topSpendKey;
  var topSpend = 0.0;
  String? topIncomeKey;
  var topIncome = 0.0;
  for (final entry in byDay.entries) {
    if (entry.value.expense > topSpend) {
      topSpend = entry.value.expense;
      topSpendKey = entry.key;
    }
    if (entry.value.income > topIncome) {
      topIncome = entry.value.income;
      topIncomeKey = entry.key;
    }
  }

  final balanceRows = isCurrentMonth
      ? (cycleBalanceRows ??
          buildBudgetBalanceRows(
            budgets,
            transactions,
            cycleStartDay: cycleStartDay,
            now: ref,
          ))
      : budgetRowsForCalendarMonth(
          budgets,
          transactions,
          viewYear,
          viewMonthIndex,
        );

  final budgetSum = balanceRows.fold<double>(0, (s, r) => s + r.limit);
  final heatBudget = isCurrentMonth
      ? (budgetSum > 0 ? budgetSum : monthlyIncome)
      : budgetSum;
  final heatDays =
      isCurrentMonth ? cycleDayCount(cycleStartDay, ref) : daysInMonth;

  final byId = {for (final b in budgets) b.id: b};
  final categories = <MonthPulseCategoryBar>[
    for (var i = 0; i < balanceRows.length; i++)
      MonthPulseCategoryBar(
        id: balanceRows[i].id,
        label: balanceRows[i].category,
        spent: balanceRows[i].spent,
        limit: balanceRows[i].limit,
        colorHex: byId[balanceRows[i].id]?.color ??
            _barColorHex[i % _barColorHex.length],
      ),
  ];

  const weeks = 6;
  final heat = List<int>.filled(weeks * 7, -1);
  for (var day = 1; day <= daysInMonth; day++) {
    final key =
        '$viewYear-${(viewMonthIndex + 1).toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    final money = byDay[key];
    final expense = money?.expense ?? 0;
    int level;
    if (expense <= 0) {
      level = 0;
    } else if (heatBudget > 0 && heatDays > 0) {
      level = dailySpendHeatLevel(expense, heatBudget, heatDays);
    } else {
      level = amountHeatLevel(expense, maxExpense);
    }
    heat[leading + day - 1] = level;
  }

  final earliest = _earliestMonth(transactions, currentYear, currentMonth);
  final viewKey = viewYear * 12 + viewMonthIndex;
  final earliestKey = earliest.year * 12 + earliest.monthIndex;
  final currentKey = currentYear * 12 + currentMonth;

  final streak = paymentStreak ?? computePaymentStreak(transactions, ref);
  final cycleHint = cycleStartDay > 1
      ? 'Cycle from $cycleStartDay'
      : 'Calendar month';

  return MonthPulseSnapshot(
    year: viewYear,
    monthIndex: viewMonthIndex,
    monthLabel: '${_monthNames[viewMonthIndex]} $viewYear',
    cycleHint: cycleHint,
    categories: categories,
    heat: heat,
    activeDays: activeDays,
    daysInMonth: daysInMonth,
    story: MonthPulseStory(
      topSpendKey: topSpendKey,
      topSpend: topSpend,
      topIncomeKey: topIncomeKey,
      topIncome: topIncome,
    ),
    canGoPrev: viewKey > earliestKey,
    canGoNext: viewKey < currentKey,
    paymentStreak: streak,
  );
}
