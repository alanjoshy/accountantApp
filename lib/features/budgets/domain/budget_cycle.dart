// Cycle rollover / next-draft activation (web budget-cycle.ts).

import '../../activity/domain/cycle.dart';
import '../../settings/data/app_settings.dart';
import '../../transactions/data/transaction.dart';
import '../data/budget.dart';
import '../data/next_cycle_budget.dart';
import 'budget_logic.dart';

String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

List<Budget> stampUndatedBudgets(
  List<Budget> budgets,
  int cycleStartDay, [
  DateTime? now,
]) {
  final cycle = getCurrentCycleDayBounds(cycleStartDay, now);
  return [
    for (final b in budgets)
      if (!hasCustomBudgetRange(b))
        b.copyWith(startDate: cycle.start, endDate: cycle.end)
      else
        b,
  ];
}

List<Budget> copyCycleRows({
  required List<Budget> source,
  required ({String start, String end}) target,
  required double Function(Budget) limitFor,
}) {
  final now = DateTime.now().toUtc().toIso8601String();
  return [
    for (final b in source)
      Budget(
        id: _newId(),
        category: b.category,
        limit: limitFor(b) < 0 ? 0 : limitFor(b),
        period: 'monthly',
        startDate: target.start,
        endDate: target.end,
        createdAt: now,
      ),
  ];
}

double plannedLimit(NextCycleBudget draft, Budget budget) {
  final next = draft.limits[budget.id];
  if (next != null && next.isFinite) return next < 0 ? 0 : next;
  return budget.limit < 0 ? 0 : budget.limit;
}

/// Apply next-cycle draft when due. Returns updated budgets/settings.
({List<Budget> budgets, AppSettings settings, bool activated})
    activateNextCycleIfDue({
  required AppSettings settings,
  required List<Budget> budgets,
  DateTime? now,
}) {
  final draft = settings.nextCycleBudget;
  if (draft == null || draft.cycleStart.isEmpty) {
    return (budgets: budgets, settings: settings, activated: false);
  }

  final today = toCycleDayKey(now ?? DateTime.now());
  if (today.compareTo(draft.cycleStart) < 0) {
    return (budgets: budgets, settings: settings, activated: false);
  }

  final cycleStartDay = settings.cycleStartDay;
  final current = getCurrentCycleDayBounds(cycleStartDay, now);
  final previous = getPreviousCycleDayBounds(cycleStartDay, now);
  final source = [for (final b in budgets) if (matchesBounds(b, previous)) b];
  final currentRows = [
    for (final b in budgets) if (matchesBounds(b, current)) b,
  ];

  if (currentRows.isEmpty && source.isEmpty) {
    return (budgets: budgets, settings: settings, activated: false);
  }

  var nextBudgets = [...budgets];
  if (currentRows.isEmpty) {
    nextBudgets = [
      ...nextBudgets,
      ...copyCycleRows(
        source: source,
        target: current,
        limitFor: (b) => plannedLimit(draft, b),
      ),
    ];
  } else if (source.isNotEmpty) {
    final limitByCategory = <String, double>{
      for (final b in source)
        b.category.trim().toLowerCase(): plannedLimit(draft, b),
    };
    nextBudgets = [
      for (final row in nextBudgets)
        if (matchesBounds(row, current))
          row.copyWith(
            limit: limitByCategory[row.category.trim().toLowerCase()] ??
                row.limit,
          )
        else
          row,
    ];
  }

  final nextSettings = settings.copyWith(
    monthlyIncome: draft.monthlyIncome,
    activeCycleStart: draft.cycleStart,
    clearNextCycleBudget: true,
  );

  return (budgets: nextBudgets, settings: nextSettings, activated: true);
}

({List<Budget> budgets, AppSettings settings}) rolloverCycleBudgets({
  required AppSettings settings,
  required List<Budget> budgets,
  DateTime? now,
}) {
  if (settings.nextCycleBudget?.cycleStart != null &&
      settings.nextCycleBudget!.cycleStart.isNotEmpty) {
    return (budgets: budgets, settings: settings);
  }

  final cycleStartDay = settings.cycleStartDay;
  final current = getCurrentCycleDayBounds(cycleStartDay, now);
  final hasCurrent = budgets.any((b) => matchesBounds(b, current));

  if (settings.activeCycleStart == current.start && hasCurrent) {
    return (budgets: budgets, settings: settings);
  }

  if (hasCurrent) {
    return (
      budgets: budgets,
      settings: settings.copyWith(activeCycleStart: current.start),
    );
  }

  final previous = getPreviousCycleDayBounds(cycleStartDay, now);
  final source = [for (final b in budgets) if (matchesBounds(b, previous)) b];
  var nextBudgets = budgets;
  if (source.isNotEmpty) {
    nextBudgets = [
      ...budgets,
      ...copyCycleRows(
        source: source,
        target: current,
        limitFor: (b) => b.limit,
      ),
    ];
  }

  return (
    budgets: nextBudgets,
    settings: settings.copyWith(
      activeCycleStart: current.start,
      clearNextCycleBudget: true,
    ),
  );
}

/// Convenience used when planning next cycle from UI.
NextCycleBudget draftForNextCycle({
  required List<Budget> currentCycleBudgets,
  required List<MoneyTransaction> transactions,
  required double monthlyIncome,
  required int cycleStartDay,
  required bool carryForward,
  NextCycleBudget? existing,
  DateTime? now,
}) {
  if (existing != null) return existing;
  return buildNextCycleDraft(
    budgets: currentCycleBudgets,
    transactions: transactions,
    monthlyIncome: monthlyIncome,
    cycleStartDay: cycleStartDay,
    carryForward: carryForward,
    now: now,
  );
}
