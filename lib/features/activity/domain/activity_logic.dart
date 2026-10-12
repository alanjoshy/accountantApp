// Pure Activity filters and breakdowns (web activity.ts).

import '../../transactions/data/transaction.dart';

enum ActivityTypeFilter { all, income, expense }

enum ActivityPeriodFilter { d7, d30, month, all }

class BreakdownRow {
  const BreakdownRow({
    required this.key,
    required this.label,
    required this.amount,
    required this.count,
    required this.share,
  });

  final String key;
  final String label;
  final double amount;
  final int count;
  final double share;
}

class DailySpendPoint {
  const DailySpendPoint({
    required this.key,
    required this.label,
    required this.shortLabel,
    required this.amount,
  });

  final String key;
  final String label;
  final String shortLabel;
  final double amount;
}

class DayGroup {
  const DayGroup({
    required this.key,
    required this.heading,
    required this.credit,
    required this.debit,
    required this.items,
  });

  final String key;
  final String heading;
  final double credit;
  final double debit;
  final List<MoneyTransaction> items;
}

DateTime _startOfLocalDay(DateTime d) => DateTime(d.year, d.month, d.day);

String toDayKey(String isoDate) {
  final d = DateTime.tryParse(isoDate);
  if (d == null) return isoDate.length >= 10 ? isoDate.substring(0, 10) : isoDate;
  final local = d.toLocal();
  final m = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$m-$day';
}

String formatDayHeadingWithWeekday(String dayKey) {
  final parts = dayKey.split('-');
  if (parts.length != 3) return dayKey;
  final d = DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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
  return '${weekdays[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
}

({DateTime start, DateTime end})? getActivityPeriodRange(
  ActivityPeriodFilter period, [
  DateTime? now,
]) {
  if (period == ActivityPeriodFilter.all) return null;
  final ref = now ?? DateTime.now();
  final end = _startOfLocalDay(ref).add(
    const Duration(hours: 23, minutes: 59, seconds: 59, milliseconds: 999),
  );
  var start = _startOfLocalDay(ref);
  if (period == ActivityPeriodFilter.d7) {
    start = start.subtract(const Duration(days: 6));
  } else if (period == ActivityPeriodFilter.d30) {
    start = start.subtract(const Duration(days: 29));
  } else {
    start = DateTime(ref.year, ref.month, 1);
  }
  return (start: start, end: end);
}

List<MoneyTransaction> filterActivityTransactions(
  List<MoneyTransaction> transactions, {
  required ActivityTypeFilter type,
  required ActivityPeriodFilter period,
  String search = '',
  String? category,
  String? tag,
  DateTime? now,
}) {
  final range = getActivityPeriodRange(period, now);
  final q = search.trim().toLowerCase();

  return transactions.where((t) {
    if (t.type == TransactionType.transfer) return false;
    if (type == ActivityTypeFilter.income && t.type != TransactionType.income) {
      return false;
    }
    if (type == ActivityTypeFilter.expense &&
        t.type != TransactionType.expense) {
      return false;
    }
    if (range != null && !_inRange(t.date, range.start, range.end)) {
      return false;
    }
    if (category != null && t.category != category) return false;
    if (!_matchesTag(t, tag)) return false;
    if (q.isNotEmpty && !_matchesSearch(t, q)) return false;
    return true;
  }).toList();
}

bool _inRange(String iso, DateTime start, DateTime end) {
  final d = DateTime.tryParse(iso);
  if (d == null) return false;
  final local = d.toLocal();
  return !local.isBefore(start) && !local.isAfter(end);
}

bool _matchesTag(MoneyTransaction t, String? tag) {
  if (tag == null) return true;
  if (tag == '__none__') return t.tags.isEmpty;
  return t.tags.contains(tag);
}

bool _matchesSearch(MoneyTransaction t, String q) {
  if (t.title.toLowerCase().contains(q)) return true;
  if (t.category.toLowerCase().contains(q)) return true;
  if ((t.note ?? '').toLowerCase().contains(q)) return true;
  return t.tags.any((tag) => tag.toLowerCase().contains(q));
}

({double income, double expense, double net}) sumByType(
  List<MoneyTransaction> transactions,
) {
  var income = 0.0;
  var expense = 0.0;
  for (final t in transactions) {
    if (t.type == TransactionType.income) {
      income += t.amount;
    } else if (t.type == TransactionType.expense) {
      expense += t.amount;
    }
  }
  return (income: income, expense: expense, net: income - expense);
}

List<BreakdownRow> buildCategoryBreakdown(
  List<MoneyTransaction> transactions,
) {
  final map = <String, ({double amount, int count})>{};
  var total = 0.0;
  for (final t in transactions) {
    final cur = map[t.category] ?? (amount: 0.0, count: 0);
    map[t.category] = (amount: cur.amount + t.amount, count: cur.count + 1);
    total += t.amount;
  }
  final rows = [
    for (final e in map.entries)
      BreakdownRow(
        key: e.key,
        label: e.key,
        amount: e.value.amount,
        count: e.value.count,
        share: total > 0 ? e.value.amount / total : 0,
      ),
  ]..sort((a, b) => b.amount.compareTo(a.amount));
  return rows;
}

List<BreakdownRow> buildExpenseCategoryBreakdown(
  List<MoneyTransaction> transactions,
) {
  return buildCategoryBreakdown([
    for (final t in transactions)
      if (t.type == TransactionType.expense) t,
  ]);
}

List<BreakdownRow> buildTagBreakdown(List<MoneyTransaction> transactions) {
  final map = <String, ({double amount, int count})>{};
  var total = 0.0;
  for (final t in transactions) {
    if (t.tags.isEmpty) {
      final cur = map['__none__'] ?? (amount: 0.0, count: 0);
      map['__none__'] = (amount: cur.amount + t.amount, count: cur.count + 1);
      total += t.amount;
      continue;
    }
    for (final tag in t.tags) {
      final cur = map[tag] ?? (amount: 0.0, count: 0);
      map[tag] = (amount: cur.amount + t.amount, count: cur.count + 1);
      total += t.amount;
    }
  }
  final rows = [
    for (final e in map.entries)
      BreakdownRow(
        key: e.key,
        label: e.key == '__none__' ? 'No tag' : e.key,
        amount: e.value.amount,
        count: e.value.count,
        share: total > 0 ? e.value.amount / total : 0,
      ),
  ]..sort((a, b) => b.amount.compareTo(a.amount));
  return rows;
}

List<DailySpendPoint> buildDailySpending(
  List<MoneyTransaction> transactions,
  ActivityPeriodFilter period, [
  DateTime? now,
]) {
  final expenses = [
    for (final t in transactions)
      if (t.type == TransactionType.expense) t,
  ];
  final range = getActivityPeriodRange(
    period == ActivityPeriodFilter.all ? ActivityPeriodFilter.d30 : period,
    now,
  );
  final end = range?.end ?? (now ?? DateTime.now());
  final start = range?.start ??
      _startOfLocalDay(end).subtract(const Duration(days: 29));

  final byDay = <String, double>{};
  for (final t in expenses) {
    final d = DateTime.tryParse(t.date)?.toLocal();
    if (d == null) continue;
    if (d.isBefore(start) || d.isAfter(end)) continue;
    final key = toDayKey(t.date);
    byDay[key] = (byDay[key] ?? 0) + t.amount;
  }

  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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

  final points = <DailySpendPoint>[];
  var cursor = _startOfLocalDay(start);
  final endDay = _startOfLocalDay(end);
  while (!cursor.isAfter(endDay)) {
    final m = cursor.month.toString().padLeft(2, '0');
    final day = cursor.day.toString().padLeft(2, '0');
    final key = '${cursor.year}-$m-$day';
    final weekday = weekdays[cursor.weekday - 1];
    points.add(
      DailySpendPoint(
        key: key,
        label: '$weekday, ${months[cursor.month - 1]} ${cursor.day}',
        shortLabel: points.length <= 10
            ? '$weekday ${cursor.day}'
            : '${cursor.day}',
        amount: byDay[key] ?? 0,
      ),
    );
    cursor = cursor.add(const Duration(days: 1));
  }
  return points;
}

List<DayGroup> groupTransactionsByDay(List<MoneyTransaction> transactions) {
  final map = <String, DayGroup>{};
  for (final t in transactions) {
    if (t.type == TransactionType.transfer) continue;
    final key = toDayKey(t.date);
    final existing = map[key];
    if (existing == null) {
      map[key] = DayGroup(
        key: key,
        heading: formatDayHeadingWithWeekday(key),
        credit: t.type == TransactionType.income ? t.amount : 0,
        debit: t.type == TransactionType.expense ? t.amount : 0,
        items: [t],
      );
    } else {
      map[key] = DayGroup(
        key: key,
        heading: existing.heading,
        credit: existing.credit +
            (t.type == TransactionType.income ? t.amount : 0),
        debit: existing.debit +
            (t.type == TransactionType.expense ? t.amount : 0),
        items: [...existing.items, t],
      );
    }
  }
  final groups = map.values.toList()
    ..sort((a, b) => b.key.compareTo(a.key));
  return groups;
}

double totalBudgetPool(Iterable<double> limits, double monthlyIncome) {
  final allocated = limits.fold<double>(0, (s, l) => s + (l > 0 ? l : 0));
  if (allocated > 0) return allocated;
  return monthlyIncome > 0 ? monthlyIncome : 0;
}
