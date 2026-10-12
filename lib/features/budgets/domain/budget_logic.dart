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
