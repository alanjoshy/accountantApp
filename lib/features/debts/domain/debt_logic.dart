// Pure debt helpers (web debts.ts).

import '../../home/presentation/data/static_remember_tips.dart';
import '../data/debt.dart';

const debtReminderWindowDays = 3;

String todayKey([DateTime? now]) {
  final d = now ?? DateTime.now();
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

/// Whole days from today to due (negative = overdue).
int daysUntilDue(String dueDate, [DateTime? now]) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final parts = dueDate.split('-');
  if (parts.length < 3) return 0;
  final y = int.tryParse(parts[0]) ?? today.year;
  final m = int.tryParse(parts[1]) ?? 1;
  final d = int.tryParse(parts[2]) ?? 1;
  final due = DateTime(y, m, d);
  return due.difference(today).inDays;
}

DebtKind debtKind(Debt debt) =>
    debt.kind == DebtKind.borrow ? DebtKind.borrow : DebtKind.lend;

double debtPaid(Debt debt) {
  final paid = debt.amountPaid;
  return paid.isFinite && paid > 0 ? paid : 0;
}

double debtRemaining(Debt debt) =>
    (debt.amount - debtPaid(debt)).clamp(0.0, double.infinity);

String normalizePersonKey(String name) => name.trim().toLowerCase();

List<String> personNameSuggestions(List<Debt> debts) {
  final seen = <String, String>{};
  for (final d in debts) {
    final raw = d.personName.trim();
    if (raw.isEmpty) continue;
    final key = normalizePersonKey(raw);
    seen.putIfAbsent(key, () => raw);
  }
  final names = seen.values.toList()..sort();
  return names;
}

class PersonNet {
  const PersonNet({
    required this.name,
    required this.lendRemaining,
    required this.borrowRemaining,
    required this.net,
  });

  final String name;
  final double lendRemaining;
  final double borrowRemaining;
  /// Positive = they owe you; negative = you owe them.
  final double net;
}

List<PersonNet> personNetBalances(List<Debt> openDebts) {
  final map = <String, ({String name, double lend, double borrow})>{};

  for (final d in openDebts) {
    if (d.status != DebtStatus.open) continue;
    final remaining = debtRemaining(d);
    if (remaining <= 0) continue;
    final key = normalizePersonKey(d.personName);
    if (key.isEmpty) continue;
    final cur = map[key] ?? (name: d.personName.trim(), lend: 0.0, borrow: 0.0);
    map[key] = debtKind(d) == DebtKind.lend
        ? (name: cur.name, lend: cur.lend + remaining, borrow: cur.borrow)
        : (name: cur.name, lend: cur.lend, borrow: cur.borrow + remaining);
  }

  final out = map.values
      .map(
        (p) => PersonNet(
          name: p.name,
          lendRemaining: p.lend,
          borrowRemaining: p.borrow,
          net: p.lend - p.borrow,
        ),
      )
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  return out;
}

String formatDebtDay(String dayKey) {
  final parts = dayKey.split('-');
  if (parts.length != 3) return dayKey;
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (m == null || d == null) return dayKey;
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
  if (m < 1 || m > 12) return dayKey;
  return '${months[m - 1]} $d';
}

String daysLeftLabel(int days) {
  if (days < 0) {
    final n = days.abs();
    return n == 1 ? '1 day overdue' : '$n days overdue';
  }
  if (days == 0) return 'due today';
  if (days == 1) return '1 day left';
  return '$days days left';
}

({String text, bool urgent}) dueHint(String dueDate, [DateTime? now]) {
  final days = daysUntilDue(dueDate, now);
  if (days < 0) {
    final n = days.abs();
    return (
      text: n == 1 ? '1 day overdue' : '$n days overdue',
      urgent: true,
    );
  }
  if (days == 0) return (text: 'Due today', urgent: true);
  if (days == 1) return (text: '1 day left', urgent: true);
  if (days <= 5) return (text: '$days days left', urgent: true);
  return (text: 'Due ${formatDebtDay(dueDate)}', urgent: false);
}

/// Open debts due within 5 days (or overdue) for Home “Things to remember”.
List<StaticRememberTip> buildDebtReminderTips(
  List<Debt> debts, {
  DateTime? now,
  required String Function(double) formatMoney,
  int windowDays = debtReminderWindowDays,
}) {
  final tips = <StaticRememberTip>[];
  final ref = now ?? DateTime.now();
  final window = windowDays < 0 ? debtReminderWindowDays : windowDays;

  for (final debt in debts) {
    if (debt.status != DebtStatus.open) continue;
    final days = daysUntilDue(debt.dueDate, ref);
    if (days > window) continue;
    final remaining = debtRemaining(debt);
    if (remaining <= 0) continue;

    final left = daysLeftLabel(days);
    final tone = days <= 1 ? RememberTone.warning : RememberTone.info;
    final kind = debtKind(debt);
    final action = kind == DebtKind.borrow
        ? 'Repay ${formatMoney(remaining)} to ${debt.personName}'
        : 'Collect ${formatMoney(remaining)} from ${debt.personName}';

    tips.add(
      StaticRememberTip(
        id: 'debt-${debt.id}',
        title: '${debt.personName} · $left',
        body: '$action — due ${formatDebtDay(debt.dueDate)}.',
        tone: tone,
        hrefLabel: 'Open debts',
      ),
    );
  }

  tips.sort((a, b) {
    final idA = a.id.replaceFirst('debt-', '');
    final idB = b.id.replaceFirst('debt-', '');
    Debt? debtA;
    Debt? debtB;
    for (final d in debts) {
      if (d.id == idA) debtA = d;
      if (d.id == idB) debtB = d;
    }
    if (debtA == null || debtB == null) return 0;
    return daysUntilDue(debtA.dueDate, ref)
        .compareTo(daysUntilDue(debtB.dueDate, ref));
  });
  return tips;
}
