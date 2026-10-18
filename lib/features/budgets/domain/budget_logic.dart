// Pure budget window / spend helpers (web budget-status.ts + budget-cycle.ts).

import '../../activity/domain/cycle.dart';
import '../../transactions/data/transaction.dart';
import '../data/budget.dart';
import '../data/next_cycle_budget.dart';

bool hasCustomBudgetRange(Budget budget) => budget.hasCustomRange;

bool budgetRangesOverlap(Budget budget, String start, String end) {
  final aStart = budget.startDate?.trim();
  final aEnd = budget.endDate?.trim();
  if (aStart == null || aStart.isEmpty || aEnd == null || aEnd.isEmpty) {
    return true;
  }
  return aStart.compareTo(end) <= 0 && aEnd.compareTo(start) >= 0;
}

bool isCycleScopedBudget(Budget budget, ({String start, String end}) cycle) {
  if (!hasCustomBudgetRange(budget)) return true;
  return budget.startDate!.trim() == cycle.start &&
      budget.endDate!.trim() == cycle.end;
}

bool matchesBounds(Budget budget, ({String start, String end}) bounds) {
  return budget.startDate?.trim() == bounds.start &&
      budget.endDate?.trim() == bounds.end;
}

List<Budget> listedBudgetsForWindow(
  List<Budget> budgets,
  ({String start, String end}) bounds, {
  bool includeUndated = false,
}) {
  return [
    for (final b in budgets)
      if (hasCustomBudgetRange(b)
          ? budgetRangesOverlap(b, bounds.start, bounds.end)
          : includeUndated)
        b,
  ];
}

List<Budget> _extraCustomInWindow(
  List<Budget> budgets,
  ({String start, String end}) window,
  List<({String start, String end})> exclude,
) {
  return [
    for (final b in budgets)
      if (hasCustomBudgetRange(b) &&
          !exclude.any((bound) => matchesBounds(b, bound)) &&
          budgetRangesOverlap(b, window.start, window.end))
        b,
  ];
}

List<Budget> previousCycleDisplayBudgets(
  List<Budget> budgets,
  ({String start, String end}) previousBounds,
  ({String start, String end}) currentBounds,
) {
  final exact = [for (final b in budgets) if (matchesBounds(b, previousBounds)) b];
  return [
    ...exact,
    ..._extraCustomInWindow(budgets, previousBounds, [
      previousBounds,
      currentBounds,
    ]),
  ];
}

({List<Budget> budgets, bool isPreview}) nextCycleDisplayBudgets(
  List<Budget> budgets,
  List<Budget> currentCycleBudgets,
  ({String start, String end}) currentBounds,
  ({String start, String end}) nextBounds,
  NextCycleBudget? draft,
) {
  final exactNext = [
    for (final b in budgets) if (matchesBounds(b, nextBounds)) b,
  ];
  final extras = _extraCustomInWindow(budgets, nextBounds, [
    nextBounds,
    currentBounds,
  ]);

  if (exactNext.isNotEmpty) {
    return (budgets: [...exactNext, ...extras], isPreview: false);
  }

  final overlay = [
    for (final b in currentCycleBudgets)
      b.copyWith(
        limit: draft != null && draft.limits.containsKey(b.id)
            ? draft.limits[b.id]!
            : b.limit,
        startDate: nextBounds.start,
        endDate: nextBounds.end,
      ),
  ];
  return (budgets: [...overlay, ...extras], isPreview: true);
}

String _dayKey(String dateIso) {
  if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(dateIso)) {
    return dateIso.substring(0, 10);
  }
  final d = DateTime.tryParse(dateIso);
  if (d == null) return dateIso;
  return toCycleDayKey(d.toLocal());
}

bool isInDateRange(String dateIso, String startDate, String endDate) {
  final key = _dayKey(dateIso);
  return key.compareTo(startDate) >= 0 && key.compareTo(endDate) <= 0;
}

bool isInCycleWindow(String dateIso, int cycleStartDay, [DateTime? now]) {
  final bounds = getCurrentCycleDayBounds(cycleStartDay, now);
  return isInDateRange(dateIso, bounds.start, bounds.end);
}

double spentForBudget(
  Budget budget,
  List<MoneyTransaction> transactions, {
  DateTime? now,
  int cycleStartDay = 1,
}) {
  return transactions.fold<double>(0, (sum, t) {
    if (t.type != TransactionType.expense || t.category != budget.category) {
      return sum;
    }
    final inWindow = hasCustomBudgetRange(budget)
        ? isInDateRange(
            t.date,
            budget.startDate!.trim(),
            budget.endDate!.trim(),
          )
        : isInCycleWindow(t.date, cycleStartDay, now);
    return inWindow ? sum + t.amount : sum;
  });
}

/// Previous calendar month (not cash-flow cycle) — web previousCalendarMonth.
({int year, int monthIndex, String label}) previousCalendarMonth([
  DateTime? now,
]) {
  final n = now ?? DateTime.now();
  final d = DateTime(n.year, n.month - 1, 1);
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
  return (
    year: d.year,
    monthIndex: d.month - 1,
    label: '${months[d.month - 1]} ${d.year}',
  );
}

bool isInCalendarMonth(String dateIso, int year, int monthIndex) {
  if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(dateIso)) {
    final y = int.tryParse(dateIso.substring(0, 4));
    final m = int.tryParse(dateIso.substring(5, 7));
    return y == year && m == monthIndex + 1;
  }
  final d = DateTime.tryParse(dateIso)?.toLocal();
  if (d == null) return false;
  return d.year == year && d.month == monthIndex + 1;
}

double spentInCalendarMonth(
  String category,
  List<MoneyTransaction> transactions,
  int year,
  int monthIndex,
) {
  return transactions.fold<double>(0, (sum, t) {
    if (t.type != TransactionType.expense || t.category != category) {
      return sum;
    }
    return isInCalendarMonth(t.date, year, monthIndex) ? sum + t.amount : sum;
  });
}

({String start, String end}) calendarMonthBounds(int year, int monthIndex) {
  final start =
      '$year-${(monthIndex + 1).toString().padLeft(2, '0')}-01';
  final lastDay = DateTime(year, monthIndex + 2, 0).day;
  final end =
      '$year-${(monthIndex + 1).toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}';
  return (start: start, end: end);
}

int overlapDaysInBounds(Budget budget, ({String start, String end}) bounds) {
  if (!hasCustomBudgetRange(budget)) {
    return inclusiveDayCount(bounds.start, bounds.end);
  }
  final a0 = budget.startDate!.trim();
  final a1 = budget.endDate!.trim();
  final start = a0.compareTo(bounds.start) > 0 ? a0 : bounds.start;
  final end = a1.compareTo(bounds.end) < 0 ? a1 : bounds.end;
  if (start.compareTo(end) > 0) return 0;
  return inclusiveDayCount(start, end);
}

/// Category rows for a past calendar month (web budgetRowsForCalendarMonth).
List<BudgetBalanceRow> budgetRowsForCalendarMonth(
  List<Budget> budgets,
  List<MoneyTransaction> transactions,
  int year,
  int monthIndex,
) {
  final bounds = calendarMonthBounds(year, monthIndex);
  var source = listedBudgetsForWindow(
    budgets,
    bounds,
    includeUndated: true,
  ).where((b) => b.limit > 0).toList();

  if (source.isEmpty) {
    source = [for (final b in budgets) if (b.limit > 0) b];
  }

  final best = <String, Budget>{};
  for (final b in source) {
    final key = b.category.trim().toLowerCase();
    if (key.isEmpty) continue;
    final existing = best[key];
    if (existing == null) {
      best[key] = b;
      continue;
    }
    final nextOverlap = overlapDaysInBounds(b, bounds);
    final prevOverlap = overlapDaysInBounds(existing, bounds);
    if (nextOverlap > prevOverlap ||
        (nextOverlap == prevOverlap && b.limit > existing.limit)) {
      best[key] = b;
    }
  }

  return [
    for (final b in best.values)
      BudgetBalanceRow(
        id: b.id,
        category: b.category,
        limit: b.limit,
        spent: spentInCalendarMonth(b.category, transactions, year, monthIndex),
      ),
  ];
}

/// Daily spend vs total budget ÷ cycle days → 0–4 heat level.
int dailySpendHeatLevel(
  double dayExpense,
  double totalBudget,
  int cycleDays,
) {
  if (!(dayExpense > 0) || !(totalBudget > 0) || !(cycleDays > 0)) return 0;
  final dailyAllowance = totalBudget / cycleDays;
  if (!(dailyAllowance > 0)) return 0;
  final ratio = dayExpense / dailyAllowance;
  if (ratio <= 0) return 0;
  if (ratio < 0.5) return 1;
  if (ratio < 0.85) return 2;
  if (ratio < 1) return 3;
  return 4;
}

int amountHeatLevel(double amount, double max) {
  if (max <= 0 || amount <= 0) return 1;
  final ratio = amount / max;
  if (ratio >= 0.75) return 4;
  if (ratio >= 0.45) return 3;
  if (ratio >= 0.2) return 2;
  return 1;
}

double totalAllocated(Iterable<Budget> budgets) {
  return budgets.fold<double>(
    0,
    (sum, b) => sum + (b.limit.isFinite ? b.limit : 0),
  );
}

double remainingToAllocate(double monthlyIncome, Iterable<Budget> budgets) {
  final left = monthlyIncome - totalAllocated(budgets);
  return left < 0 ? 0 : left;
}

double unaccountedSpendInRange(
  List<Budget> budgets,
  List<MoneyTransaction> transactions,
  String start,
  String end,
) {
  final budgetCats = {
    for (final b in budgets)
      if (b.category.trim().isNotEmpty) b.category.trim().toLowerCase(),
  };
  return transactions.fold<double>(0, (sum, t) {
    if (t.type != TransactionType.expense) return sum;
    final cat = t.category.trim().toLowerCase();
    if (cat.isEmpty || budgetCats.contains(cat)) return sum;
    return isInDateRange(t.date, start, end) ? sum + t.amount : sum;
  });
}

Map<String, double> carryForwardByCategory(
  List<Budget> budgets,
  List<MoneyTransaction> transactions,
  int cycleStartDay, [
  DateTime? now,
]) {
  final map = <String, double>{};
  for (final b in budgets) {
    if (!(b.limit > 0)) continue;
    final spent = spentForBudget(
      b,
      transactions,
      now: now,
      cycleStartDay: cycleStartDay,
    );
    final left = b.limit - spent;
    map[b.id] = left < 0 ? 0 : left;
  }
  return map;
}

NextCycleBudget buildNextCycleDraft({
  required List<Budget> budgets,
  required List<MoneyTransaction> transactions,
  required double monthlyIncome,
  required int cycleStartDay,
  required bool carryForward,
  DateTime? now,
}) {
  final ref = now ?? DateTime.now();
  final current = getCurrentCycleDayBounds(cycleStartDay, ref);
  final next = getNextCycleDayBounds(cycleStartDay, ref);
  final leftover = carryForward
      ? carryForwardByCategory(budgets, transactions, cycleStartDay, ref)
      : const <String, double>{};

  final limits = <String, double>{};
  for (final b in budgets) {
    if (!isCycleScopedBudget(b, current)) continue;
    final base = b.limit > 0 ? b.limit : 0.0;
    limits[b.id] = base + (leftover[b.id] ?? 0);
  }

  return NextCycleBudget(
    cycleStart: next.start,
    monthlyIncome: monthlyIncome,
    limits: limits,
    carryForward: carryForward,
    preparedAt: ref.toUtc().toIso8601String(),
  );
}

class BudgetBalanceRow {
  const BudgetBalanceRow({
    required this.id,
    required this.category,
    required this.limit,
    required this.spent,
  });

  final String id;
  final String category;
  final double limit;
  final double spent;

  double get remaining {
    final left = limit - spent;
    return left < 0 ? 0 : left;
  }
}

List<BudgetBalanceRow> buildBudgetBalanceRows(
  List<Budget> budgets,
  List<MoneyTransaction> transactions, {
  int cycleStartDay = 1,
  DateTime? now,
}) {
  return [
    for (final b in budgets)
      if (b.limit > 0)
        BudgetBalanceRow(
          id: b.id,
          category: b.category,
          limit: b.limit,
          spent: spentForBudget(
            b,
            transactions,
            now: now,
            cycleStartDay: cycleStartDay,
          ),
        ),
  ];
}
