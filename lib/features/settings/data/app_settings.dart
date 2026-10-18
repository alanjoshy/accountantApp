// App settings for cash flow + tags + next-cycle draft + add defaults + reminders.

import '../../accounts/domain/payments.dart';
import '../../budgets/data/next_cycle_budget.dart';

enum DefaultDateMode { today, remember }

/// How planned reserves fold into next-cycle budget limits.
enum PlannedReserveAllocationMode { ask, auto }

class AppSettings {
  const AppSettings({
    this.tags = const [],
    this.monthlyIncome = 0,
    this.cycleStartDay = 1,
    this.nextCycleBudget,
    this.activeCycleStart,
    this.defaultCategory = 'Food',
    this.defaultTag,
    this.defaultDateMode = DefaultDateMode.today,
    this.lastTransactionDate,
    this.defaultAccountId,
    this.defaultPaymentMode = PaymentMode.upi,
    this.lowBalanceThreshold = 500,
    this.lowBalanceEnabled = true,
    this.notificationsEnabled = true,
    this.dailyLogReminderEnabled = true,
    this.dailyLogReminderHour = 20,
    this.dailyLogReminderMinute = 0,
    this.budgetRemindersEnabled = true,
    this.scheduledRemindersEnabled = true,
    this.debtRemindersEnabled = true,
    this.debtReminderLeadDays = 3,
    this.scheduledReminderLeadDays = 5,
    this.plannedReservesEnabled = true,
    this.plannedReserveAllocationMode = PlannedReserveAllocationMode.ask,
  });

  final List<String> tags;
  final double monthlyIncome;
  final int cycleStartDay;
  final NextCycleBudget? nextCycleBudget;
  final String? activeCycleStart;
  final String defaultCategory;
  final String? defaultTag;
  final DefaultDateMode defaultDateMode;
  final String? lastTransactionDate;
  final String? defaultAccountId;
  final PaymentMode defaultPaymentMode;
  final double lowBalanceThreshold;
  final bool lowBalanceEnabled;

  final bool notificationsEnabled;
  final bool dailyLogReminderEnabled;
  final int dailyLogReminderHour;
  final int dailyLogReminderMinute;
  final bool budgetRemindersEnabled;
  final bool scheduledRemindersEnabled;
  final bool debtRemindersEnabled;
  final int debtReminderLeadDays;
  final int scheduledReminderLeadDays;
  final bool plannedReservesEnabled;
  final PlannedReserveAllocationMode plannedReserveAllocationMode;

  AppSettings copyWith({
    List<String>? tags,
    double? monthlyIncome,
    int? cycleStartDay,
    NextCycleBudget? nextCycleBudget,
    String? activeCycleStart,
    String? defaultCategory,
    String? defaultTag,
    DefaultDateMode? defaultDateMode,
    String? lastTransactionDate,
    String? defaultAccountId,
    PaymentMode? defaultPaymentMode,
    double? lowBalanceThreshold,
    bool? lowBalanceEnabled,
    bool? notificationsEnabled,
    bool? dailyLogReminderEnabled,
    int? dailyLogReminderHour,
    int? dailyLogReminderMinute,
    bool? budgetRemindersEnabled,
    bool? scheduledRemindersEnabled,
    bool? debtRemindersEnabled,
    int? debtReminderLeadDays,
    int? scheduledReminderLeadDays,
    bool? plannedReservesEnabled,
    PlannedReserveAllocationMode? plannedReserveAllocationMode,
    bool clearNextCycleBudget = false,
    bool clearActiveCycleStart = false,
    bool clearDefaultTag = false,
    bool clearLastTransactionDate = false,
    bool clearDefaultAccountId = false,
  }) {
    return AppSettings(
      tags: tags ?? this.tags,
      monthlyIncome: monthlyIncome ?? this.monthlyIncome,
      cycleStartDay: cycleStartDay ?? this.cycleStartDay,
      nextCycleBudget: clearNextCycleBudget
          ? null
          : (nextCycleBudget ?? this.nextCycleBudget),
      activeCycleStart: clearActiveCycleStart
          ? null
          : (activeCycleStart ?? this.activeCycleStart),
      defaultCategory: defaultCategory ?? this.defaultCategory,
      defaultTag: clearDefaultTag ? null : (defaultTag ?? this.defaultTag),
      defaultDateMode: defaultDateMode ?? this.defaultDateMode,
      lastTransactionDate: clearLastTransactionDate
          ? null
          : (lastTransactionDate ?? this.lastTransactionDate),
      defaultAccountId: clearDefaultAccountId
          ? null
          : (defaultAccountId ?? this.defaultAccountId),
      defaultPaymentMode: defaultPaymentMode ?? this.defaultPaymentMode,
      lowBalanceThreshold: lowBalanceThreshold ?? this.lowBalanceThreshold,
      lowBalanceEnabled: lowBalanceEnabled ?? this.lowBalanceEnabled,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      dailyLogReminderEnabled:
          dailyLogReminderEnabled ?? this.dailyLogReminderEnabled,
      dailyLogReminderHour: dailyLogReminderHour ?? this.dailyLogReminderHour,
      dailyLogReminderMinute:
          dailyLogReminderMinute ?? this.dailyLogReminderMinute,
      budgetRemindersEnabled:
          budgetRemindersEnabled ?? this.budgetRemindersEnabled,
      scheduledRemindersEnabled:
          scheduledRemindersEnabled ?? this.scheduledRemindersEnabled,
      debtRemindersEnabled: debtRemindersEnabled ?? this.debtRemindersEnabled,
      debtReminderLeadDays: debtReminderLeadDays ?? this.debtReminderLeadDays,
      scheduledReminderLeadDays:
          scheduledReminderLeadDays ?? this.scheduledReminderLeadDays,
      plannedReservesEnabled:
          plannedReservesEnabled ?? this.plannedReservesEnabled,
      plannedReserveAllocationMode: plannedReserveAllocationMode ??
          this.plannedReserveAllocationMode,
    );
  }

  Map<String, dynamic> toJson() => {
        'tags': tags,
        'monthlyIncome': monthlyIncome,
        'cycleStartDay': cycleStartDay,
        if (nextCycleBudget != null)
          'nextCycleBudget': nextCycleBudget!.toJson(),
        if (activeCycleStart != null && activeCycleStart!.isNotEmpty)
          'activeCycleStart': activeCycleStart,
        'defaultCategory': defaultCategory,
        if (defaultTag != null && defaultTag!.isNotEmpty)
          'defaultTag': defaultTag,
        'defaultDateMode':
            defaultDateMode == DefaultDateMode.remember ? 'remember' : 'today',
        if (lastTransactionDate != null && lastTransactionDate!.isNotEmpty)
          'lastTransactionDate': lastTransactionDate,
        if (defaultAccountId != null && defaultAccountId!.isNotEmpty)
          'defaultAccountId': defaultAccountId,
        'defaultPaymentMode': defaultPaymentMode.name,
        'lowBalanceThreshold': lowBalanceThreshold,
        'lowBalanceEnabled': lowBalanceEnabled,
        'notificationsEnabled': notificationsEnabled,
        'dailyLogReminderEnabled': dailyLogReminderEnabled,
        'dailyLogReminderHour': dailyLogReminderHour,
        'dailyLogReminderMinute': dailyLogReminderMinute,
        'budgetRemindersEnabled': budgetRemindersEnabled,
        'scheduledRemindersEnabled': scheduledRemindersEnabled,
        'debtRemindersEnabled': debtRemindersEnabled,
        'debtReminderLeadDays': debtReminderLeadDays,
        'scheduledReminderLeadDays': scheduledReminderLeadDays,
        'plannedReservesEnabled': plannedReservesEnabled,
        'plannedReserveAllocationMode':
            plannedReserveAllocationMode == PlannedReserveAllocationMode.auto
                ? 'auto'
                : 'ask',
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'] as List<dynamic>? ?? const [];
    final tags = [for (final t in rawTags) t.toString()];
    final rawDraft = json['nextCycleBudget'];
    final cat = (json['defaultCategory'] as String?)?.trim();
    final tagRaw = (json['defaultTag'] as String?)?.trim();
    String? defaultTag;
    if (tagRaw != null && tagRaw.isNotEmpty) {
      for (final t in tags) {
        if (t.toLowerCase() == tagRaw.toLowerCase()) {
          defaultTag = t;
          break;
        }
      }
    }
    final modeRaw = json['defaultDateMode'] as String?;
    final last = json['lastTransactionDate'] as String?;
    final lastOk = last != null && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(last)
        ? last
        : null;
    final threshold = (json['lowBalanceThreshold'] as num?)?.toDouble();
    final hour = (json['dailyLogReminderHour'] as num?)?.toInt() ?? 20;
    final minute = (json['dailyLogReminderMinute'] as num?)?.toInt() ?? 0;
    final debtLead = (json['debtReminderLeadDays'] as num?)?.toInt() ?? 3;
    final schedLead = (json['scheduledReminderLeadDays'] as num?)?.toInt() ?? 5;

    return AppSettings(
      tags: tags,
      monthlyIncome: (json['monthlyIncome'] as num?)?.toDouble() ?? 0,
      cycleStartDay: (json['cycleStartDay'] as num?)?.toInt() ?? 1,
      nextCycleBudget: rawDraft is Map
          ? NextCycleBudget.fromJson(Map<String, dynamic>.from(rawDraft))
          : null,
      activeCycleStart: json['activeCycleStart'] as String?,
      defaultCategory: (cat == null || cat.isEmpty) ? 'Food' : cat,
      defaultTag: defaultTag,
      defaultDateMode: modeRaw == 'remember'
          ? DefaultDateMode.remember
          : DefaultDateMode.today,
      lastTransactionDate: lastOk,
      defaultAccountId: json['defaultAccountId']?.toString(),
      defaultPaymentMode: normalizePaymentMode(json['defaultPaymentMode']),
      lowBalanceThreshold:
          threshold != null && threshold.isFinite && threshold >= 0
              ? threshold
              : 500,
      lowBalanceEnabled: json['lowBalanceEnabled'] as bool? ?? true,
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      dailyLogReminderEnabled:
          json['dailyLogReminderEnabled'] as bool? ?? true,
      dailyLogReminderHour: hour.clamp(0, 23),
      dailyLogReminderMinute: minute.clamp(0, 59),
      budgetRemindersEnabled: json['budgetRemindersEnabled'] as bool? ?? true,
      scheduledRemindersEnabled:
          json['scheduledRemindersEnabled'] as bool? ?? true,
      debtRemindersEnabled: json['debtRemindersEnabled'] as bool? ?? true,
      debtReminderLeadDays: debtLead.clamp(1, 14),
      scheduledReminderLeadDays: schedLead.clamp(1, 14),
      plannedReservesEnabled: json['plannedReservesEnabled'] as bool? ?? true,
      plannedReserveAllocationMode:
          json['plannedReserveAllocationMode'] == 'auto'
              ? PlannedReserveAllocationMode.auto
              : PlannedReserveAllocationMode.ask,
    );
  }
}
