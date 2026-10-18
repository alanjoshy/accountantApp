// Dynamic “Things to remember” tips (web insights.ts subset).

import '../../accounts/data/account.dart';
import '../../scheduled/data/scheduled_payment.dart';
import '../../scheduled/domain/scheduled_logic.dart';
import '../../activity/domain/cycle.dart';
import '../../budgets/data/budget.dart';
import '../../budgets/domain/budget_logic.dart';
import '../../debts/data/debt.dart';
import '../../debts/domain/debt_logic.dart';
import '../../transactions/data/transaction.dart';
import '../presentation/data/static_remember_tips.dart';
import 'home_logic.dart';

List<StaticRememberTip> buildSecurityTips({
  required bool hasPin,
  required bool protectAccountBalances,
  required bool hasAccounts,
}) {
  final tips = <StaticRememberTip>[];
  if (!hasPin) {
    if (hasAccounts) {
      tips.add(
        const StaticRememberTip(
          id: 'security-no-pin',
          title: 'Set a PIN in Settings',
          body:
              'Lock Accountant and optionally hide account balances behind PIN or biometrics.',
          tone: RememberTone.info,
          hrefLabel: 'Open settings',
        ),
      );
    }
    return tips;
  }
  if (hasAccounts && !protectAccountBalances) {
    tips.add(
      const StaticRememberTip(
        id: 'security-protect-balances',
        title: 'Hide account balances',
        body:
            'Turn on “Protect account balances” in Settings so amounts stay masked until you unlock.',
        tone: RememberTone.info,
        hrefLabel: 'Open settings',
      ),
    );
  }
  return tips;
}

List<StaticRememberTip> buildAccountTips({
  required List<MoneyAccount> accounts,
  required String? defaultAccountId,
  required bool lowBalanceEnabled,
  required double lowBalanceThreshold,
  required String Function(double) formatMoney,
  bool revealBalances = true,
}) {
  final tips = <StaticRememberTip>[];
  if (accounts.isEmpty) {
    tips.add(
      const StaticRememberTip(
        id: 'accounts-empty',
        title: 'Add a bank or cash account',
        body:
            'Track where money sits — set a default debit account for spends and income.',
        tone: RememberTone.info,
        hrefLabel: 'Open accounts',
      ),
    );
    return tips;
  }

  if (defaultAccountId == null ||
      !accounts.any((a) => a.id == defaultAccountId)) {
    tips.add(
      const StaticRememberTip(
        id: 'accounts-no-default',
        title: 'Set a default debit account',
        body:
            'Choose which account should be used when you add a transaction.',
        tone: RememberTone.info,
        hrefLabel: 'Open accounts',
      ),
    );
  }

  if (lowBalanceEnabled && lowBalanceThreshold >= 0) {
    MoneyAccount? focus;
    for (final a in accounts) {
      if (a.id == defaultAccountId) {
        focus = a;
        break;
      }
    }
    focus ??= accounts.reduce(
      (a, b) => a.balance <= b.balance ? a : b,
    );
    if (focus.balance <= lowBalanceThreshold) {
      final body = revealBalances
          ? '${focus.name} has ${formatMoney(focus.balance)} left (alert at ${formatMoney(lowBalanceThreshold)}).'
          : '${focus.name} is at or below your low-balance alert. Unlock balances to see the amount.';
      tips.add(
        StaticRememberTip(
          id: 'low-balance-${focus.id}',
          title: 'Low balance · ${focus.name}',
          body: body,
          tone: RememberTone.warning,
          hrefLabel: 'Open accounts',
        ),
      );
    }
  }

  return tips;
}

int _daySpan(DateTime start, DateTime end) {
  final days = dateOnly(end).difference(dateOnly(start)).inDays;
  if (days < 0) return 1;
  return days + 1;
}

int _expenseSpanDays(
  List<MoneyTransaction> expenses,
  ({DateTime start, DateTime end})? range,
) {
  if (range != null) return _daySpan(range.start, range.end);
  if (expenses.isEmpty) return 1;
  DateTime? min;
  DateTime? max;
  for (final t in expenses) {
    final key = transactionDayKey(t.date);
    final d = DateTime.tryParse('${key}T12:00:00');
    if (d == null) continue;
    min = min == null || d.isBefore(min) ? d : min;
    max = max == null || d.isAfter(max) ? d : max;
  }
  if (min == null || max == null) return 1;
  return _daySpan(min, max);
}

({int elapsed, int remaining}) _budgetWindowDays(
  Budget budget,
  int cycleStartDay,
  DateTime now,
) {
  final today = dateOnly(now);

  if (hasCustomBudgetRange(budget)) {
    final start =
        DateTime.tryParse('${budget.startDate!.trim()}T12:00:00') ?? today;
    final end =
        DateTime.tryParse('${budget.endDate!.trim()}T12:00:00') ?? today;
    final rangeStart = dateOnly(start);
    final rangeEnd = dateOnly(end);
    final capped = today.isAfter(rangeEnd) ? rangeEnd : today;
    final elapsed = _daySpan(rangeStart, capped).clamp(1, 9999);
    final remaining = today.isAfter(rangeEnd)
        ? 0
        : (_daySpan(today, rangeEnd) - 1).clamp(0, 9999);
    return (elapsed: elapsed, remaining: remaining);
  }

  final range = getCurrentCycleRange(cycleStartDay, now);
  final elapsed = _daySpan(dateOnly(range.start), today).clamp(1, 9999);
  final remaining =
      (_daySpan(today, dateOnly(range.end)) - 1).clamp(0, 9999);
  return (elapsed: elapsed, remaining: remaining);
}

bool _hasBudgetForNextCycle(
  List<Budget> budgets,
  int cycleStartDay,
  DateTime now,
) {
  final next = getNextCycleDayBounds(cycleStartDay, now);
  return budgets.any((b) {
    if (!hasCustomBudgetRange(b)) return false;
    final start = b.startDate!.trim();
    final end = b.endDate!.trim();
    return start.compareTo(next.end) <= 0 && end.compareTo(next.start) >= 0;
  });
}

StaticRememberTip? buildBudgetSetupReminderTip(
  List<Budget> budgets,
  int cycleStartDay, [
  DateTime? now,
]) {
  final ref = now ?? DateTime.now();
  if (!isNextCyclePlanningWindow(cycleStartDay, ref)) return null;
  final days = daysUntilNextCycle(cycleStartDay, ref);
  if (_hasBudgetForNextCycle(budgets, cycleStartDay, ref)) return null;

  final nextBounds = getNextCycleDayBounds(cycleStartDay, ref);
  final rangeLabel = formatBoundsLabel(nextBounds);
  final title = days == 0
      ? "Set up next month's budget today"
      : days == 1
          ? '1 day left · set up next budget'
          : '$days days left · set up next budget';
  final body = budgets.isEmpty
      ? 'Your cash-flow month starts $rangeLabel. Add category limits before it begins.'
      : 'Review or set category limits for $rangeLabel so next month starts planned.';

  return StaticRememberTip(
    id: 'budget-setup-next',
    title: title,
    body: body,
    tone: days <= 1 ? RememberTone.warning : RememberTone.info,
    hrefLabel: 'Open budgets',
  );
}

List<StaticRememberTip> buildSpendSpeedTips(
  List<Budget> budgets,
  List<MoneyTransaction> transactions,
  int cycleStartDay,
  String Function(double) formatMoney, [
  DateTime? now,
]) {
  final tips = <StaticRememberTip>[];
  final ref = now ?? DateTime.now();

  for (final budget in budgets) {
    if (budget.limit <= 0) continue;
    final spent = spentForBudget(
      budget,
      transactions,
      now: ref,
      cycleStartDay: cycleStartDay,
    );
    final window = _budgetWindowDays(budget, cycleStartDay, ref);
    final leftover = budget.limit - spent;
    final dailyRate = spent / window.elapsed;

    if (leftover <= 0) {
      tips.add(
        StaticRememberTip(
          id: 'speed-over-${budget.category}',
          title: '${budget.category} is over budget',
          body:
              "You've already spent ${formatMoney(spent)} of ${formatMoney(budget.limit)} on ${budget.category}. Pause non-essential buys here.",
          tone: RememberTone.warning,
          hrefLabel: 'Open budgets',
        ),
      );
      continue;
    }

    if (dailyRate <= 0) continue;
    final daysUntilOver = leftover / dailyRate;
    final willOvershoot = (window.remaining > 0 &&
            daysUntilOver < window.remaining) ||
        daysUntilOver <= 7;
    if (!willOvershoot) continue;

    final daysRounded = daysUntilOver.round().clamp(1, 9999);
    final safeDaily = (window.remaining > 0
            ? (leftover / window.remaining).floorToDouble()
            : leftover.floorToDouble())
        .clamp(0.0, leftover)
        .toDouble();

    tips.add(
      StaticRememberTip(
        id: 'speed-${budget.category}',
        title: '${budget.category} spending too fast',
        body:
            'If you keep spending like this, ${budget.category} will go over in about $daysRounded day${daysRounded == 1 ? '' : 's'}. Reduce daily ${budget.category} spend to about ${formatMoney(safeDaily)}.',
        tone: RememberTone.warning,
        hrefLabel: 'Open budgets',
      ),
    );
  }

  tips.sort((a, b) {
    final overFirst = (a.id.startsWith('speed-over-') ? 1 : 0) -
        (b.id.startsWith('speed-over-') ? 1 : 0);
    if (overFirst != 0) return -overFirst;
    return a.title.compareTo(b.title);
  });
  return tips.take(2).toList();
}

/// Build short “things to remember” cards from cycle transactions + budgets.
List<StaticRememberTip> buildRememberTips({
  required List<MoneyTransaction> transactions,
  required List<Budget> budgets,
  required int cycleStartDay,
  required String Function(double) formatMoney,
  List<Debt> debts = const [],
  List<MoneyAccount> accounts = const [],
  List<ScheduledPayment> scheduledPayments = const [],
  String? defaultAccountId,
  bool lowBalanceEnabled = true,
  double lowBalanceThreshold = 500,
  bool hasPin = false,
  bool protectAccountBalances = false,
  bool revealBalances = true,
  List<MoneyTransaction>? allTransactions,
  DateTime? now,
  String periodLabel = 'this cycle',
}) {
  final tips = <StaticRememberTip>[];
  final ref = now ?? DateTime.now();
  final range = getCurrentCycleRange(cycleStartDay, ref);
  final bounds = getCurrentCycleDayBounds(cycleStartDay, ref);
  final periodTx = [
    for (final t in transactions)
      if (transactionDayKey(t.date).compareTo(bounds.start) >= 0 &&
          transactionDayKey(t.date).compareTo(bounds.end) <= 0)
        t,
  ];
  final expenses = [
    for (final t in periodTx)
      if (t.type == TransactionType.expense) t,
  ];
  final income = [
    for (final t in periodTx)
      if (t.type == TransactionType.income) t,
  ];
  final totalExpense = expenses.fold<double>(0, (s, t) => s + t.amount);
  final totalIncome = income.fold<double>(0, (s, t) => s + t.amount);
  final days = _expenseSpanDays(expenses, (start: range.start, end: range.end));
  final dailyAvg = days > 0 ? totalExpense / days : 0.0;
  final budgetTx = allTransactions ?? transactions;

  tips.addAll(
    buildSecurityTips(
      hasPin: hasPin,
      protectAccountBalances: protectAccountBalances,
      hasAccounts: accounts.isNotEmpty,
    ),
  );

  tips.addAll(
    buildAccountTips(
      accounts: accounts,
      defaultAccountId: defaultAccountId,
      lowBalanceEnabled: lowBalanceEnabled,
      lowBalanceThreshold: lowBalanceThreshold,
      formatMoney: formatMoney,
      revealBalances: revealBalances,
    ),
  );

  final budgetSetup = buildBudgetSetupReminderTip(budgets, cycleStartDay, ref);
  if (budgetSetup != null) tips.add(budgetSetup);

  tips.addAll(
    buildDebtReminderTips(debts, now: ref, formatMoney: formatMoney),
  );

  tips.addAll(
    buildScheduledPaymentReminderTips(
      scheduledPayments,
      formatMoney: formatMoney,
      now: ref,
    ),
  );

  final cycleBudgets = listedBudgetsForWindow(
    budgets,
    bounds,
    includeUndated: true,
  );
  tips.addAll(
    buildSpendSpeedTips(
      cycleBudgets,
      budgetTx,
      cycleStartDay,
      formatMoney,
      ref,
    ),
  );

  if (expenses.isEmpty && tips.isEmpty) {
    tips.add(
      const StaticRememberTip(
        id: 'empty',
        title: 'Track a few spends',
        body:
            'Add recent expenses so we can show your daily average and category tips for this period.',
        tone: RememberTone.info,
      ),
    );
    return tips;
  }

  if (expenses.isNotEmpty) {
    tips.add(
      StaticRememberTip(
        id: 'daily-avg',
        title: 'Average daily spend',
        body:
            "You're averaging ${formatMoney(dailyAvg)} per day across $periodLabel ($days day${days == 1 ? '' : 's'}).",
        tone: RememberTone.info,
      ),
    );
  }

  if (totalIncome > 0 && totalExpense > totalIncome) {
    tips.add(
      StaticRememberTip(
        id: 'overspend',
        title: 'Spending ahead of income',
        body:
            'Expenses are ${formatMoney(totalExpense - totalIncome)} above income in this period. Slow non-essential buys if you can.',
        tone: RememberTone.warning,
      ),
    );
  } else if (totalIncome > 0 &&
      totalExpense > 0 &&
      totalExpense <= totalIncome * 0.7) {
    tips.add(
      const StaticRememberTip(
        id: 'healthy',
        title: 'Spending looks steady',
        body:
            "You're under about 70% of income this period — a solid cushion for savings or your jar goals.",
        tone: RememberTone.success,
      ),
    );
  }

  if (tips.length < 2) {
    tips.add(
      const StaticRememberTip(
        id: 'habit',
        title: 'Small daily check-in',
        body:
            'Glance at today’s spends once — catching little leaks early keeps the period average down.',
        tone: RememberTone.info,
      ),
    );
  }

  final priority = tips
      .where(
        (t) =>
            t.id.startsWith('speed-') ||
            t.id.startsWith('debt-') ||
            t.id.startsWith('sched-') ||
            t.id.startsWith('low-balance-') ||
            t.id.startsWith('accounts-') ||
            t.id == 'budget-setup-next',
      )
      .toList();
  final rest = tips.where((t) => !priority.contains(t)).toList();
  return [...priority, ...rest].take(6).toList();
}
