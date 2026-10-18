// Cash-flow cycle helpers (web cycle.ts essentials).

int clampCycleStartDay(int day) {
  if (day < 1) return 1;
  if (day > 28) return 28;
  return day;
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String toCycleDayKey(DateTime d) {
  final local = dateOnly(d);
  final m = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$m-$day';
}

({DateTime start, DateTime end}) getCurrentCycleRange(
  int startDay, [
  DateTime? ref,
]) {
  final day = clampCycleStartDay(startDay);
  final now = ref ?? DateTime.now();
  final y = now.year;
  final m = now.month;
  final d = now.day;

  final cycleStart =
      d >= day ? DateTime(y, m, day) : DateTime(y, m - 1, day);

  final nextStart = DateTime(cycleStart.year, cycleStart.month + 1, day);
  final cycleEnd = nextStart.subtract(const Duration(milliseconds: 1));
  return (start: cycleStart, end: cycleEnd);
}

({String start, String end}) getCurrentCycleDayBounds(
  int startDay, [
  DateTime? ref,
]) {
  final range = getCurrentCycleRange(startDay, ref);
  return (start: toCycleDayKey(range.start), end: toCycleDayKey(range.end));
}

({String start, String end}) getPreviousCycleDayBounds(
  int startDay, [
  DateTime? ref,
]) {
  final current = getCurrentCycleRange(startDay, ref);
  final dayBefore = dateOnly(current.start).subtract(const Duration(days: 1));
  return getCurrentCycleDayBounds(startDay, dayBefore);
}

DateTime getNextCycleStart(int startDay, [DateTime? ref]) {
  final day = clampCycleStartDay(startDay);
  final current = getCurrentCycleRange(day, ref);
  return DateTime(current.start.year, current.start.month + 1, day);
}

({String start, String end}) getNextCycleDayBounds(
  int startDay, [
  DateTime? ref,
]) {
  final day = clampCycleStartDay(startDay);
  final nextStart = getNextCycleStart(day, ref);
  final following = DateTime(nextStart.year, nextStart.month + 1, day);
  final nextEnd = following.subtract(const Duration(milliseconds: 1));
  return (start: toCycleDayKey(nextStart), end: toCycleDayKey(nextEnd));
}

int cycleDayCount(int startDay, [DateTime? ref]) {
  final range = getCurrentCycleRange(startDay, ref);
  final start = dateOnly(range.start);
  final end = dateOnly(range.end);
  final days = end.difference(start).inDays + 1;
  return days < 1 ? 1 : days;
}

int daysUntilNextCycle(int startDay, [DateTime? ref]) {
  final now = ref ?? DateTime.now();
  final today = dateOnly(now);
  final next = getNextCycleStart(startDay, now);
  return next.difference(today).inDays;
}

/// How many days before the next cycle the planner / reminder may appear.
const nextCyclePlanLeadDays = 5;

/// Mid-month starts stay in that calendar month (5th → from the 1st).
int nextCyclePlanWindowDays(int startDay) {
  final day = clampCycleStartDay(startDay);
  if (day <= 1) return nextCyclePlanLeadDays;
  return day - 1 < nextCyclePlanLeadDays ? day - 1 : nextCyclePlanLeadDays;
}

bool isNextCyclePlanningWindow(int startDay, [DateTime? ref]) {
  final days = daysUntilNextCycle(startDay, ref);
  return days > 0 && days <= nextCyclePlanWindowDays(startDay);
}

int cycleElapsedDays(int startDay, [DateTime? ref]) {
  final now = ref ?? DateTime.now();
  final range = getCurrentCycleRange(startDay, now);
  final start = dateOnly(range.start);
  final today = dateOnly(now);
  final end = dateOnly(range.end);
  if (today.isBefore(start)) return 0;
  final capped = today.isAfter(end) ? end : today;
  return capped.difference(start).inDays + 1;
}

int inclusiveDayCount(String start, String end) {
  final s = DateTime.tryParse('${start.trim()}T12:00:00');
  final e = DateTime.tryParse('${end.trim()}T12:00:00');
  if (s == null || e == null || e.isBefore(s)) return 1;
  final days = e.difference(s).inDays + 1;
  return days < 1 ? 1 : days;
}

String formatDateRange(DateTime start, DateTime end) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  String fmt(DateTime d) => '${months[d.month - 1]} ${d.day}';
  if (start.year == end.year) {
    return '${fmt(start)} – ${fmt(end)}, ${end.year}';
  }
  return '${fmt(start)}, ${start.year} – ${fmt(end)}, ${end.year}';
}

String formatBoundsLabel(({String start, String end}) bounds) {
  final s = DateTime.tryParse('${bounds.start}T12:00:00');
  final e = DateTime.tryParse('${bounds.end}T12:00:00');
  if (s == null || e == null) return '${bounds.start} – ${bounds.end}';
  return formatDateRange(s, e);
}
