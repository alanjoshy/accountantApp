// Web-compatible Accountant backup JSON (formatVersion 1).

import 'dart:convert';

import '../../accounts/data/account.dart';
import '../../accounts/domain/account_style.dart';
import '../../accounts/domain/payments.dart';
import '../../budgets/data/budget.dart';
import '../../budgets/data/next_cycle_budget.dart';
import '../../debts/data/debt.dart';
import '../../jars/data/jar_goal.dart';
import '../../planned/data/planned_reserve.dart';
import '../../scheduled/data/scheduled_payment.dart';
import '../../settings/data/app_settings.dart';
import '../../transactions/data/transaction.dart';

const backupFormatVersion = 1;
const backupAppId = 'accountant';

class BackupSnapshot {
  const BackupSnapshot({
    required this.exportedAt,
    required this.transactions,
    required this.budgets,
    required this.jars,
    required this.settings,
    this.accounts = const [],
    this.scheduledPayments = const [],
    this.plannedReserves = const [],
    this.debts = const [],
  });

  final String exportedAt;
  final List<MoneyTransaction> transactions;
  final List<Budget> budgets;
  final List<JarGoal> jars;
  final List<Map<String, dynamic>> settings;
  final List<MoneyAccount> accounts;
  final List<ScheduledPayment> scheduledPayments;
  final List<PlannedReserve> plannedReserves;
  final List<Debt> debts;

  Map<String, dynamic> toJson() => {
        'formatVersion': backupFormatVersion,
        'app': backupAppId,
        'exportedAt': exportedAt,
        'data': {
          'transactions': transactions.map((t) => t.toJson()).toList(),
          'budgets': budgets.map((b) => b.toJson()).toList(),
          'jars': jars.map((j) => j.toJson()).toList(),
          'settings': settings,
          'accounts': accounts.map((a) => a.toJson()).toList(),
          'scheduledPayments':
              scheduledPayments.map((s) => s.toJson()).toList(),
          'plannedReserves':
              plannedReserves.map((p) => p.toJson()).toList(),
          'debts': debts.map((d) => d.toJson()).toList(),
        },
      };

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}

bool isBackupSnapshot(dynamic value) {
  if (value is! Map) return false;
  final v = Map<String, dynamic>.from(value);
  if (v['formatVersion'] != backupFormatVersion) return false;
  if (v['app'] != backupAppId) return false;
  if (v['exportedAt'] is! String) return false;
  final data = v['data'];
  if (data is! Map) return false;
  final d = Map<String, dynamic>.from(data);
  return d['transactions'] is List &&
      d['budgets'] is List &&
      d['jars'] is List &&
      d['settings'] is List;
}

String _idStr(dynamic id, [String? fallback]) {
  if (id == null) {
    return fallback ?? DateTime.now().microsecondsSinceEpoch.toString();
  }
  return id.toString();
}

String _dayKey(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(raw)) return raw.substring(0, 10);
  return raw;
}

/// Parse web or Flutter backup JSON into Flutter models (IDs remapped to strings).
BackupSnapshot parseBackupJson(String text) {
  late final dynamic parsed;
  try {
    parsed = jsonDecode(text);
  } catch (_) {
    throw StateError('Backup file is not valid JSON');
  }
  if (!isBackupSnapshot(parsed)) {
    throw StateError('This file is not an Accountant backup');
  }
  final root = Map<String, dynamic>.from(parsed as Map);
  final data = Map<String, dynamic>.from(root['data'] as Map);

  final accountIdMap = <String, String>{};
  final accountsRaw = data['accounts'] as List<dynamic>? ?? const [];
  final accounts = <MoneyAccount>[];
  for (final row in accountsRaw) {
    if (row is! Map) continue;
    final m = Map<String, dynamic>.from(row);
    final oldId = _idStr(m['id']);
    accountIdMap[oldId] = oldId;
    final kind = normalizeAccountKind(m['kind']);
    accounts.add(
      MoneyAccount(
        id: oldId,
        name: m['name']?.toString() ?? 'Account',
        kind: kind,
        balance: (m['balance'] as num?)?.toDouble() ?? 0,
        icon: m['icon']?.toString(),
        color: m['color']?.toString(),
        createdAt: m['createdAt']?.toString() ?? '',
        updatedAt: m['updatedAt']?.toString() ?? '',
      ),
    );
  }

  String? mapAccount(dynamic raw) {
    if (raw == null) return null;
    final key = raw.toString();
    return accountIdMap[key] ?? key;
  }

  final txIdMap = <String, String>{};
  final txsRaw = data['transactions'] as List<dynamic>? ?? const [];
  final transactions = <MoneyTransaction>[];
  for (final row in txsRaw) {
    if (row is! Map) continue;
    final m = Map<String, dynamic>.from(row);
    final id = _idStr(m['id']);
    txIdMap[_idStr(m['id'])] = id;
    final typeName = m['type']?.toString() ?? 'expense';
    final type = TransactionType.values.firstWhere(
      (t) => t.name == typeName,
      orElse: () => TransactionType.expense,
    );
    final tagsRaw = m['tags'];
    transactions.add(
      MoneyTransaction(
        id: id,
        title: m['title']?.toString() ?? '',
        amount: (m['amount'] as num?)?.toDouble() ?? 0,
        type: type,
        category: m['category']?.toString() ?? '',
        date: _dayKey(m['date']?.toString()),
        createdAt: m['createdAt']?.toString() ?? m['date']?.toString() ?? '',
        note: m['note']?.toString(),
        tags: tagsRaw is List
            ? [for (final t in tagsRaw) t.toString()]
            : const [],
        paymentMode: tryParsePaymentMode(m['paymentMode']),
        accountId: mapAccount(m['accountId']),
        toAccountId: mapAccount(m['toAccountId']),
      ),
    );
  }

  final budgetsRaw = data['budgets'] as List<dynamic>? ?? const [];
  final budgets = <Budget>[];
  for (final row in budgetsRaw) {
    if (row is! Map) continue;
    final m = Map<String, dynamic>.from(row);
    budgets.add(
      Budget(
        id: _idStr(m['id']),
        category: m['category']?.toString() ?? '',
        limit: (m['limit'] as num?)?.toDouble() ?? 0,
        period: m['period']?.toString() ?? 'monthly',
        startDate: m['startDate']?.toString(),
        endDate: m['endDate']?.toString(),
        icon: m['icon']?.toString() ?? 'more',
        color: m['color']?.toString() ?? '#3b82f6',
        createdAt: m['createdAt']?.toString() ?? '',
      ),
    );
  }

  final jarsRaw = data['jars'] as List<dynamic>? ?? const [];
  final jars = <JarGoal>[];
  for (final row in jarsRaw) {
    if (row is! Map) continue;
    final m = Map<String, dynamic>.from(row);
    final updatesRaw = m['updates'] as List<dynamic>? ?? const [];
    jars.add(
      JarGoal(
        id: _idStr(m['id']),
        name: m['name']?.toString() ?? '',
        targetAmount: (m['targetAmount'] as num?)?.toDouble() ?? 0,
        currentAmount: (m['currentAmount'] as num?)?.toDouble() ?? 0,
        color: m['color']?.toString() ?? '#22c55e',
        icon: m['icon']?.toString() ?? 'jar',
        createdAt: m['createdAt']?.toString() ?? '',
        updatedAt: m['updatedAt']?.toString() ?? '',
        updates: [
          for (final u in updatesRaw)
            if (u is Map)
              JarUpdate.fromJson(Map<String, dynamic>.from(u)),
        ],
      ),
    );
  }

  final debtsRaw = data['debts'] as List<dynamic>? ?? const [];
  final debts = <Debt>[];
  for (final row in debtsRaw) {
    if (row is! Map) continue;
    final m = Map<String, dynamic>.from(row);
    final kindRaw = m['kind']?.toString();
    final statusRaw = m['status']?.toString();
    debts.add(
      Debt(
        id: _idStr(m['id']),
        personName: m['personName']?.toString() ?? '',
        amount: (m['amount'] as num?)?.toDouble() ?? 0,
        amountPaid: (m['amountPaid'] as num?)?.toDouble() ?? 0,
        lentDate: _dayKey(m['lentDate']?.toString()),
        dueDate: _dayKey(m['dueDate']?.toString()),
        kind: kindRaw == 'borrow' ? DebtKind.borrow : DebtKind.lend,
        status:
            statusRaw == 'collected' ? DebtStatus.collected : DebtStatus.open,
        note: m['note']?.toString(),
        createdAt: m['createdAt']?.toString() ?? '',
        updatedAt: m['updatedAt']?.toString() ?? '',
      ),
    );
  }

  final schedRaw = data['scheduledPayments'] as List<dynamic>? ?? const [];
  final scheduled = <ScheduledPayment>[];
  for (final row in schedRaw) {
    if (row is! Map) continue;
    final m = Map<String, dynamic>.from(row);
    final status = switch (m['status']?.toString().toLowerCase()) {
      'paid' => ScheduleStatus.paid,
      'skipped' => ScheduleStatus.skipped,
      'cancelled' || 'canceled' => ScheduleStatus.cancelled,
      _ => ScheduleStatus.pending,
    };
    final repeat = switch (m['repeat']?.toString().toLowerCase()) {
      'daily' => ScheduleRepeat.daily,
      'weekly' => ScheduleRepeat.weekly,
      'monthly' => ScheduleRepeat.monthly,
      _ => ScheduleRepeat.once,
    };
    final tagsRaw = m['tags'];
    final txRef = m['transactionId'];
    scheduled.add(
      ScheduledPayment(
        id: _idStr(m['id']),
        title: m['title']?.toString() ?? '',
        amount: (m['amount'] as num?)?.toDouble() ?? 0,
        category: m['category']?.toString() ?? '',
        dueDate: _dayKey(m['dueDate']?.toString()),
        status: status,
        repeat: repeat,
        accountId: mapAccount(m['accountId']) ?? '',
        paymentMode: normalizePaymentMode(m['paymentMode']),
        tags: tagsRaw is List
            ? [for (final t in tagsRaw) t.toString()]
            : const [],
        note: m['note']?.toString(),
        paidAt: m['paidAt']?.toString(),
        transactionId: txRef == null ? null : (txIdMap[_idStr(txRef)] ?? _idStr(txRef)),
        deletedAt: m['deletedAt']?.toString(),
        createdAt: m['createdAt']?.toString() ?? '',
        updatedAt: m['updatedAt']?.toString() ?? '',
      ),
    );
  }

  final settingsRaw = data['settings'] as List<dynamic>? ?? const [];
  final settings = <Map<String, dynamic>>[
    for (final row in settingsRaw)
      if (row is Map) Map<String, dynamic>.from(row),
  ];

  // Remap defaultAccountId in settings rows.
  for (final s in settings) {
    if (s.containsKey('defaultAccountId')) {
      s['defaultAccountId'] = mapAccount(s['defaultAccountId']);
    }
  }

  final plannedRaw = data['plannedReserves'] as List<dynamic>? ?? const [];
  final planned = <PlannedReserve>[];
  for (final row in plannedRaw) {
    if (row is! Map) continue;
    try {
      planned.add(
        PlannedReserve.fromJson(Map<String, dynamic>.from(row)),
      );
    } catch (_) {}
  }

  return BackupSnapshot(
    exportedAt: root['exportedAt'] as String,
    transactions: transactions,
    budgets: budgets,
    jars: jars,
    settings: settings,
    accounts: accounts,
    scheduledPayments: scheduled,
    plannedReserves: planned,
    debts: debts,
  );
}

/// Merge first settings row from backup into Flutter [AppSettings].
AppSettings mergeSettingsFromBackup(
  AppSettings current,
  List<Map<String, dynamic>> rows,
) {
  if (rows.isEmpty) return current;
  final s = rows.first;
  final tagsRaw = s['tags'] as List<dynamic>? ?? const [];
  final tags = [for (final t in tagsRaw) t.toString()];
  final modeRaw = s['defaultDateMode']?.toString();
  final last = s['lastTransactionDate']?.toString();
  final lastOk =
      last != null && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(last) ? last : null;

  NextCycleBudget? draft;
  final rawDraft = s['nextCycleBudget'];
  if (rawDraft is Map) {
    try {
      draft = NextCycleBudget.fromJson(Map<String, dynamic>.from(rawDraft));
    } catch (_) {}
  }

  final reminderTime = s['dailyExpenseReminderTime']?.toString();
  var hour = current.dailyLogReminderHour;
  var minute = current.dailyLogReminderMinute;
  if (reminderTime != null && RegExp(r'^\d{1,2}:\d{2}$').hasMatch(reminderTime)) {
    final parts = reminderTime.split(':');
    hour = int.tryParse(parts[0])?.clamp(0, 23) ?? hour;
    minute = int.tryParse(parts[1])?.clamp(0, 59) ?? minute;
  }

  final catRaw = s['defaultCategory']?.toString().trim();
  return current.copyWith(
    tags: tags.isNotEmpty ? tags : current.tags,
    monthlyIncome: (s['monthlyIncome'] as num?)?.toDouble() ?? current.monthlyIncome,
    cycleStartDay: (s['cycleStartDay'] as num?)?.toInt() ?? current.cycleStartDay,
    nextCycleBudget: draft,
    activeCycleStart: s['activeCycleStart']?.toString(),
    defaultCategory:
        (catRaw == null || catRaw.isEmpty) ? current.defaultCategory : catRaw,
    defaultTag: s['defaultTag']?.toString(),
    defaultDateMode: modeRaw == 'remember'
        ? DefaultDateMode.remember
        : (modeRaw == 'today' ? DefaultDateMode.today : current.defaultDateMode),
    lastTransactionDate: lastOk,
    defaultAccountId: s['defaultAccountId']?.toString(),
    defaultPaymentMode: s['defaultPaymentMode'] != null
        ? normalizePaymentMode(s['defaultPaymentMode'])
        : current.defaultPaymentMode,
    dailyLogReminderEnabled:
        s['dailyExpenseReminderEnabled'] as bool? ?? current.dailyLogReminderEnabled,
    dailyLogReminderHour: hour,
    dailyLogReminderMinute: minute,
    plannedReservesEnabled:
        s['plannedReservesEnabled'] as bool? ?? current.plannedReservesEnabled,
    plannedReserveAllocationMode:
        s['plannedReserveAllocationMode'] == 'auto'
            ? PlannedReserveAllocationMode.auto
            : (s['plannedReserveAllocationMode'] == 'ask'
                ? PlannedReserveAllocationMode.ask
                : current.plannedReserveAllocationMode),
  );
}

String defaultBackupFileName([DateTime? date]) {
  final d = date ?? DateTime.now();
  final y = d.year.toString();
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  final h = d.hour.toString().padLeft(2, '0');
  final min = d.minute.toString().padLeft(2, '0');
  return 'accountant-backup-$y$m$day-$h$min.json';
}
