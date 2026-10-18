// Pure helpers for planned budget reserves.

import '../../activity/domain/cycle.dart';
import '../../budgets/data/budget.dart';
import '../../home/presentation/data/static_remember_tips.dart';
import '../data/planned_reserve.dart';

/// Active reserves whose due date falls inside [start]–[end] (day keys).
List<PlannedReserve> reservesDueInBounds(
  Iterable<PlannedReserve> items, {
  required String start,
  required String end,
}) {
  return [
    for (final r in items)
      if (r.isActive &&
          r.dueDate.compareTo(start) >= 0 &&
          r.dueDate.compareTo(end) <= 0)
        r,
  ]..sort((a, b) => a.dueDate.compareTo(b.dueDate));
}

/// Reserves expected in the upcoming cash-flow cycle.
List<PlannedReserve> reservesForNextCycle(
  Iterable<PlannedReserve> items,
  int cycleStartDay, [
  DateTime? now,
]) {
  final next = getNextCycleDayBounds(cycleStartDay, now);
  return reservesDueInBounds(items, start: next.start, end: next.end);
}

/// Not yet folded into a next-cycle plan for [cycleStart].
List<PlannedReserve> unappliedReservesForCycle(
  Iterable<PlannedReserve> items, {
  required String cycleStart,
  required String cycleEnd,
}) {
  return [
    for (final r in reservesDueInBounds(
      items,
      start: cycleStart,
      end: cycleEnd,
    ))
      if (r.appliedCycleStart != cycleStart) r,
  ];
}

/// Sum reserve amounts by budget category name.
Map<String, double> reserveTotalsByCategory(Iterable<PlannedReserve> items) {
  final map = <String, double>{};
  for (final r in items) {
    final key = r.category.trim();
    if (key.isEmpty || r.amount <= 0) continue;
    map[key] = (map[key] ?? 0) + r.amount;
  }
  return map;
}

/// Add reserve totals onto category limits (matched by budget category name).
Map<String, double> applyReserveTotalsToLimits({
  required Map<String, double> limits,
  required List<Budget> budgets,
  required Iterable<PlannedReserve> reserves,
}) {
  final byCat = reserveTotalsByCategory(reserves);
  if (byCat.isEmpty) return Map<String, double>.from(limits);
  final next = Map<String, double>.from(limits);
  for (final b in budgets) {
    final add = byCat[b.category];
    if (add == null || add <= 0) continue;
    next[b.id] = (next[b.id] ?? b.limit) + add;
  }
  return next;
}

String _formatDue(String dueDate) {
  final parts = dueDate.split('-');
  if (parts.length < 3) return dueDate;
  final m = int.tryParse(parts[1]) ?? 1;
  final d = int.tryParse(parts[2]) ?? 1;
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '$d ${months[m - 1]}';
}

/// Home tips during the ~5-day next-cycle planning window.
List<StaticRememberTip> buildPlannedReserveReminderTips(
  List<PlannedReserve> items, {
  required int cycleStartDay,
  required String Function(double) formatMoney,
  DateTime? now,
}) {
  final ref = now ?? DateTime.now();
  if (!isNextCyclePlanningWindow(cycleStartDay, ref)) return const [];

  final upcoming = reservesForNextCycle(items, cycleStartDay, ref);
  if (upcoming.isEmpty) return const [];

  final tips = <StaticRememberTip>[];
  final next = getNextCycleDayBounds(cycleStartDay, ref);
  final rangeLabel = formatBoundsLabel(next);

  if (upcoming.length == 1) {
    final r = upcoming.first;
    tips.add(
      StaticRememberTip(
        id: 'planned-${r.id}',
        title: 'Plan for ${r.title}',
        body:
            '${formatMoney(r.amount)} · ${r.category} is due ${_formatDue(r.dueDate)} '
            '($rangeLabel). Reserve it when you plan next cycle.',
        tone: RememberTone.warning,
        hrefLabel: 'Open planned reserves',
      ),
    );
  } else {
    final total = upcoming.fold<double>(0, (s, r) => s + r.amount);
    tips.add(
      StaticRememberTip(
        id: 'planned-next-cycle',
        title: '${upcoming.length} planned costs next cycle',
        body:
            '${formatMoney(total)} reserved across categories for $rangeLabel. '
            'Include them when allocating next month.',
        tone: RememberTone.warning,
        hrefLabel: 'Open planned reserves',
      ),
    );
    for (final r in upcoming.take(3)) {
      tips.add(
        StaticRememberTip(
          id: 'planned-${r.id}',
          title: r.title,
          body:
              '${formatMoney(r.amount)} · ${r.category} · ${_formatDue(r.dueDate)}',
          tone: RememberTone.info,
          hrefLabel: 'Open planned reserves',
        ),
      );
    }
  }
  return tips;
}
