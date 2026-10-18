// Pure reminder evaluation — tips + schedulable notifications.

import '../../accounts/data/account.dart';
import '../../activity/domain/cycle.dart';
import '../../budgets/data/budget.dart';
import '../../budgets/domain/budget_logic.dart';
import '../../debts/data/debt.dart';
import '../../debts/domain/debt_logic.dart';
import '../../home/domain/home_logic.dart';
import '../../home/domain/remember_tips.dart';
import '../../home/presentation/data/static_remember_tips.dart';
import '../../planned/data/planned_reserve.dart';
import '../../planned/domain/planned_logic.dart';
import '../../scheduled/data/scheduled_payment.dart';
import '../../scheduled/domain/scheduled_logic.dart';
import '../../settings/data/app_settings.dart';
import '../../transactions/data/transaction.dart';
import 'reminder_item.dart';

class ReminderEngine {
  ReminderEngine._();

  /// Active tips for Home + inbox (no future-only schedules).
  static List<ReminderItem> evaluateActive({
    required AppSettings settings,
    required List<MoneyTransaction> transactions,
    required List<Budget> budgets,
    required List<Debt> debts,
    required List<ScheduledPayment> scheduledPayments,
    required List<MoneyAccount> accounts,
    List<PlannedReserve> plannedReserves = const [],
    required String Function(double) formatMoney,
    bool hasPin = false,
    bool protectAccountBalances = false,
    bool revealBalances = true,
    DateTime? now,
  }) {
    final ref = now ?? DateTime.now();
    final tips = <ReminderItem>[];

    tips.addAll(
      _fromStaticTips(
        buildSecurityTips(
          hasPin: hasPin,
          protectAccountBalances: protectAccountBalances,
          hasAccounts: accounts.isNotEmpty,
        ),
        ReminderDeepLink.settings,
      ),
    );

    tips.addAll(
      _fromStaticTips(
        buildAccountTips(
          accounts: accounts,
          defaultAccountId: settings.defaultAccountId,
          lowBalanceEnabled: settings.lowBalanceEnabled,
          lowBalanceThreshold: settings.lowBalanceThreshold,
          formatMoney: formatMoney,
          revealBalances: revealBalances,
        ),
        ReminderDeepLink.accounts,
      ),
    );

    if (settings.budgetRemindersEnabled) {
      final current = buildCurrentBudgetPlanTip(
        budgets: budgets,
        monthlyIncome: settings.monthlyIncome,
        cycleStartDay: settings.cycleStartDay,
        now: ref,
      );
      if (current != null) tips.add(current);

      final next = buildBudgetSetupReminderTip(
        budgets,
        settings.cycleStartDay,
        ref,
      );
      if (next != null) {
        tips.add(
          ReminderItem(
            id: next.id,
            title: next.title,
            body: next.body,
            tone: next.tone,
            deepLink: ReminderDeepLink.budgets,
            hrefLabel: next.hrefLabel,
          ),
        );
      }
    }

    if (settings.dailyLogReminderEnabled) {
      final daily = buildDailyLogTip(
        transactions: transactions,
        now: ref,
      );
      if (daily != null) tips.add(daily);
    }

    if (settings.debtRemindersEnabled) {
      tips.addAll(
        _fromStaticTips(
          buildDebtReminderTips(
            debts,
            now: ref,
            formatMoney: formatMoney,
            windowDays: settings.debtReminderLeadDays,
          ),
          ReminderDeepLink.debts,
        ),
      );
    }

    if (settings.scheduledRemindersEnabled) {
      tips.addAll(
        _fromStaticTips(
          buildScheduledPaymentReminderTips(
            scheduledPayments,
            formatMoney: formatMoney,
            now: ref,
            windowDays: settings.scheduledReminderLeadDays,
          ),
          ReminderDeepLink.scheduled,
        ),
      );
    }

    if (settings.plannedReservesEnabled) {
      tips.addAll(
        _fromStaticTips(
          buildPlannedReserveReminderTips(
            plannedReserves,
            cycleStartDay: settings.cycleStartDay,
            formatMoney: formatMoney,
            now: ref,
          ),
          ReminderDeepLink.plannedReserves,
        ),
      );
    }

    final bounds = getCurrentCycleDayBounds(settings.cycleStartDay, ref);
    final cycleBudgets = listedBudgetsForWindow(
      budgets,
      bounds,
      includeUndated: true,
    );
    tips.addAll(
      _fromStaticTips(
        buildSpendSpeedTips(
          cycleBudgets,
          transactions,
          settings.cycleStartDay,
          formatMoney,
          ref,
        ),
        ReminderDeepLink.budgets,
      ),
    );

    // Priority: actionable warnings first.
    final priority = tips.where(_isPriority).toList();
    final rest = tips.where((t) => !_isPriority(t)).toList();
    return [...priority, ...rest];
  }

  /// Future OS notifications to schedule (next ~14 days).
  static List<ReminderItem> evaluateSchedules({
    required AppSettings settings,
    required List<MoneyTransaction> transactions,
    required List<Budget> budgets,
    required List<Debt> debts,
    required List<ScheduledPayment> scheduledPayments,
    required String Function(double) formatMoney,
    DateTime? now,
  }) {
    if (!settings.notificationsEnabled) return const [];

    final ref = now ?? DateTime.now();
    final out = <ReminderItem>[];

    if (settings.dailyLogReminderEnabled) {
      final todayKey = _dayKey(ref);
      final logged = transactions.any(
        (t) =>
            t.type == TransactionType.expense &&
            transactionDayKey(t.date) == todayKey,
      );
      if (!logged) {
        var fire = DateTime(
          ref.year,
          ref.month,
          ref.day,
          settings.dailyLogReminderHour,
          settings.dailyLogReminderMinute,
        );
        if (!fire.isAfter(ref)) {
          fire = fire.add(const Duration(days: 1));
        }
        // Skip tomorrow slot if somehow already logged — only schedule next open slot.
        out.add(
          ReminderItem(
            id: 'notify-daily-log-${_dayKey(fire)}',
            title: 'Log today’s spends',
            body: 'Quick check-in — add what you spent so your budget stays accurate.',
            tone: RememberTone.info,
            deepLink: ReminderDeepLink.addTransaction,
            hrefLabel: 'Add transaction',
            notifyAt: fire,
            notificationId: stableNotificationId('daily-log-${_dayKey(fire)}'),
          ),
        );
      } else {
        final tomorrow = ref.add(const Duration(days: 1));
        final fire = DateTime(
          tomorrow.year,
          tomorrow.month,
          tomorrow.day,
          settings.dailyLogReminderHour,
          settings.dailyLogReminderMinute,
        );
        out.add(
          ReminderItem(
            id: 'notify-daily-log-${_dayKey(fire)}',
            title: 'Log today’s spends',
            body: 'Quick check-in — add what you spent so your budget stays accurate.',
            tone: RememberTone.info,
            deepLink: ReminderDeepLink.addTransaction,
            hrefLabel: 'Add transaction',
            notifyAt: fire,
            notificationId: stableNotificationId('daily-log-${_dayKey(fire)}'),
          ),
        );
      }
    }

    if (settings.budgetRemindersEnabled) {
      if (isNextCyclePlanningWindow(settings.cycleStartDay, ref)) {
        final days = daysUntilNextCycle(settings.cycleStartDay, ref);
        final fire = DateTime(ref.year, ref.month, ref.day, 9, 0);
        if (fire.isAfter(ref)) {
          out.add(
            ReminderItem(
              id: 'notify-budget-next-$days',
              title: days == 1
                  ? '1 day left · set up next budget'
                  : '$days days left · set up next budget',
              body: 'Plan category limits before the next cash-flow month starts.',
              tone: days <= 1 ? RememberTone.warning : RememberTone.info,
              deepLink: ReminderDeepLink.budgets,
              hrefLabel: 'Open budgets',
              notifyAt: fire,
              notificationId: stableNotificationId('budget-next-$days'),
            ),
          );
        }
      }

      final current = buildCurrentBudgetPlanTip(
        budgets: budgets,
        monthlyIncome: settings.monthlyIncome,
        cycleStartDay: settings.cycleStartDay,
        now: ref,
      );
      if (current != null) {
        final fire = DateTime(ref.year, ref.month, ref.day, 10, 0);
        if (fire.isAfter(ref)) {
          out.add(
            current.copyWith(
              id: 'notify-${current.id}',
              notifyAt: fire,
              notificationId: stableNotificationId(current.id),
            ),
          );
        }
      }
    }

    if (settings.debtRemindersEnabled) {
      for (final debt in debts) {
        if (debt.status != DebtStatus.open) continue;
        final days = daysUntilDue(debt.dueDate, ref);
        if (days < 0 || days > settings.debtReminderLeadDays) continue;
        final remaining = debtRemaining(debt);
        if (remaining <= 0) continue;
        final due = _parseDay(debt.dueDate) ?? ref;
        final fire = DateTime(due.year, due.month, due.day, 9, 0)
            .subtract(Duration(days: days.clamp(0, settings.debtReminderLeadDays)));
        // Prefer morning of (due - lead) or today 9am if already in window.
        final when = fire.isAfter(ref)
            ? fire
            : DateTime(ref.year, ref.month, ref.day, 9, 0);
        if (!when.isAfter(ref)) continue;
        final kind = debtKind(debt);
        final action = kind == DebtKind.borrow
            ? 'Repay ${formatMoney(remaining)} to ${debt.personName}'
            : 'Collect ${formatMoney(remaining)} from ${debt.personName}';
        out.add(
          ReminderItem(
            id: 'notify-debt-${debt.id}',
            title: '${debt.personName} · due in $days day${days == 1 ? '' : 's'}',
            body: '$action — due ${formatDebtDay(debt.dueDate)}.',
            tone: days <= 1 ? RememberTone.warning : RememberTone.info,
            deepLink: ReminderDeepLink.debts,
            hrefLabel: 'Open debts',
            notifyAt: when,
            notificationId: stableNotificationId('debt-${debt.id}'),
          ),
        );
      }
    }

    if (settings.scheduledRemindersEnabled) {
      for (final payment in scheduledPayments) {
        if (payment.status != ScheduleStatus.pending) continue;
        final days = _daysUntil(payment.dueDate, ref);
        if (days < 0 || days > settings.scheduledReminderLeadDays) continue;
        final due = _parseDay(payment.dueDate) ?? ref;
        var when = DateTime(due.year, due.month, due.day, 9, 0);
        if (days > 1) {
          when = when.subtract(const Duration(days: 1));
        }
        if (!when.isAfter(ref)) {
          when = DateTime(ref.year, ref.month, ref.day, 9, 0);
        }
        if (!when.isAfter(ref)) continue;
        out.add(
          ReminderItem(
            id: 'notify-sched-${payment.id}',
            title: days <= 0
                ? 'Payment due today'
                : days == 1
                    ? 'Payment due tomorrow'
                    : 'Payment in $days days',
            body:
                '${payment.title} · ${formatMoney(payment.amount)} due ${formatDueHeading(payment.dueDate)}.',
            tone: days <= 1 ? RememberTone.warning : RememberTone.info,
            deepLink: ReminderDeepLink.scheduled,
            hrefLabel: 'Open scheduled',
            notifyAt: when,
            notificationId: stableNotificationId('sched-${payment.id}'),
          ),
        );
      }
    }

    return out;
  }

  static bool _isPriority(ReminderItem t) {
    return t.tone == RememberTone.warning ||
        t.id.startsWith('debt-') ||
        t.id.startsWith('sched-') ||
        t.id.startsWith('budget-') ||
        t.id.startsWith('daily-log') ||
        t.id.startsWith('low-balance-') ||
        t.id.startsWith('speed-');
  }

  static List<ReminderItem> _fromStaticTips(
    List<StaticRememberTip> tips,
    ReminderDeepLink link,
  ) {
    return [
      for (final t in tips)
        ReminderItem(
          id: t.id,
          title: t.title,
          body: t.body,
          tone: t.tone,
          deepLink: link,
          hrefLabel: t.hrefLabel,
        ),
    ];
  }

  static String _dayKey(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  static DateTime? _parseDay(String key) {
    final parts = key.split('-');
    if (parts.length < 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  static int _daysUntil(String dueDate, DateTime now) {
    final due = _parseDay(dueDate);
    if (due == null) return 0;
    final today = DateTime(now.year, now.month, now.day);
    return due.difference(today).inDays;
  }
}

extension on ReminderItem {
  ReminderItem copyWith({
    String? id,
    DateTime? notifyAt,
    int? notificationId,
  }) {
    return ReminderItem(
      id: id ?? this.id,
      title: title,
      body: body,
      tone: tone,
      deepLink: deepLink,
      hrefLabel: hrefLabel,
      notifyAt: notifyAt ?? this.notifyAt,
      notificationId: notificationId ?? this.notificationId,
    );
  }
}

/// Current cycle has no income and/or no allocated category limits.
ReminderItem? buildCurrentBudgetPlanTip({
  required List<Budget> budgets,
  required double monthlyIncome,
  required int cycleStartDay,
  DateTime? now,
}) {
  final ref = now ?? DateTime.now();
  final bounds = getCurrentCycleDayBounds(cycleStartDay, ref);
  final listed = listedBudgetsForWindow(
    budgets,
    bounds,
    includeUndated: true,
  );
  final allocated = listed.any((b) => b.limit > 0);
  final hasIncome = monthlyIncome > 0;
  if (hasIncome && allocated) return null;

  if (!hasIncome && !allocated) {
    return const ReminderItem(
      id: 'budget-current-unplanned',
      title: 'This month isn’t planned yet',
      body:
          'Set your income and category limits so Home and budgets can guide spending.',
      tone: RememberTone.warning,
      deepLink: ReminderDeepLink.budgets,
      hrefLabel: 'Open budgets',
    );
  }
  if (!hasIncome) {
    return const ReminderItem(
      id: 'budget-current-income',
      title: 'Set this month’s income',
      body: 'Add planned income so you can allocate budgets across categories.',
      tone: RememberTone.warning,
      deepLink: ReminderDeepLink.budgets,
      hrefLabel: 'Open budgets',
    );
  }
  return const ReminderItem(
    id: 'budget-current-allocate',
    title: 'Allocate this month’s budget',
    body: 'Income is set — split it into category limits to track spending.',
    tone: RememberTone.warning,
    deepLink: ReminderDeepLink.budgets,
    hrefLabel: 'Open budgets',
  );
}

ReminderItem? buildDailyLogTip({
  required List<MoneyTransaction> transactions,
  DateTime? now,
}) {
  final ref = now ?? DateTime.now();
  final today =
      '${ref.year}-${ref.month.toString().padLeft(2, '0')}-${ref.day.toString().padLeft(2, '0')}';
  final logged = transactions.any(
    (t) =>
        t.type == TransactionType.expense &&
        transactionDayKey(t.date) == today,
  );
  if (logged) return null;
  return const ReminderItem(
    id: 'daily-log',
    title: 'Add today’s transactions',
    body:
        'No spends logged today. A quick add keeps your balance and budgets honest.',
    tone: RememberTone.info,
    deepLink: ReminderDeepLink.addTransaction,
    hrefLabel: 'Add transaction',
  );
}
