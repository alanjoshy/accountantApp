// Persisted scheduled payments (web useScheduledPayments).

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/storage/local_storage.dart';
import '../../accounts/domain/payments.dart';
import '../../budgets/data/budget.dart';
import '../../budgets/data/budget_store.dart';
import '../../settings/data/app_settings_store.dart';
import '../../transactions/data/transaction.dart';
import '../../transactions/data/transaction_store.dart';
import '../domain/scheduled_logic.dart';
import 'scheduled_payment.dart';

class ScheduledPaymentStore extends ChangeNotifier {
  ScheduledPaymentStore();

  static final ScheduledPaymentStore instance = ScheduledPaymentStore();

  List<ScheduledPayment> _items = const [];

  List<ScheduledPayment> get all => _items;

  List<ScheduledPayment> get pending => [
        for (final p in _items)
          if (p.status == ScheduleStatus.pending) p,
      ]..sort((a, b) => a.dueDate.compareTo(b.dueDate));

  List<ScheduledPayment> get history => [
        for (final p in _items)
          if (p.status != ScheduleStatus.pending) p,
      ]..sort((a, b) {
          final aa = a.paidAt ?? a.deletedAt ?? a.updatedAt;
          final bb = b.paidAt ?? b.deletedAt ?? b.updatedAt;
          return bb.compareTo(aa);
        });

  void load() {
    final raw = LocalStorage.getString(AppConstants.scheduledPaymentsKey);
    if (raw == null || raw.isEmpty) {
      _items = const [];
      return;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      _items = [
        for (final item in list)
          ScheduledPayment.fromJson(Map<String, dynamic>.from(item as Map)),
      ];
    } catch (_) {
      _items = const [];
    }
  }

  Future<void> _persist() async {
    await LocalStorage.setString(
      AppConstants.scheduledPaymentsKey,
      jsonEncode(_items.map((p) => p.toJson()).toList()),
    );
  }

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  String _now() => DateTime.now().toUtc().toIso8601String();

  Future<ScheduledPayment> add({
    required String title,
    required double amount,
    required String category,
    required String dueDate,
    required ScheduleRepeat repeat,
    required String accountId,
    required PaymentMode paymentMode,
    List<String> tags = const [],
    String? note,
    List<Budget>? budgets,
    List<MoneyTransaction>? transactions,
    int? cycleStartDay,
  }) async {
    final check = checkBudgetExceed(
      category: category,
      amount: amount,
      dueDate: dueDate,
      repeat: repeat,
      budgets: budgets ?? BudgetStore.instance.budgets,
      transactions: transactions ?? TransactionStore.instance.transactions,
      cycleStartDay:
          cycleStartDay ?? AppSettingsStore.instance.cycleStartDay,
    );
    if (check.exceeds) {
      throw StateError(
        'Would exceed $category by ${check.overBy.toStringAsFixed(0)} '
        'this cycle (${check.occurrences} payment'
        '${check.occurrences == 1 ? '' : 's'}).',
      );
    }

    final now = _now();
    final item = ScheduledPayment(
      id: _newId(),
      title: title.trim(),
      amount: amount.abs(),
      category: category.trim(),
      dueDate: dueDate,
      status: ScheduleStatus.pending,
      repeat: repeat,
      accountId: accountId,
      paymentMode: paymentMode,
      tags: tags,
      note: note?.trim().isEmpty == true ? null : note?.trim(),
      createdAt: now,
      updatedAt: now,
    );
    _items = [..._items, item];
    notifyListeners();
    await _persist();

    if (isDueOrOverdue(dueDate)) {
      await processDue();
    }
    return item;
  }

  Future<ScheduledPayment> payNow(String id) async {
    final i = _items.indexWhere((p) => p.id == id);
    if (i < 0) throw StateError('Scheduled payment not found.');
    final item = _items[i];
    if (item.status == ScheduleStatus.paid) return item;
    if (item.status != ScheduleStatus.pending) {
      throw StateError('Only pending payments can be paid.');
    }

    final paidOn = scheduleTodayKey();
    final tx = await TransactionStore.instance.add(
      title: item.title,
      amount: item.amount,
      type: TransactionType.expense,
      category: item.category,
      date: paidOn,
      note: item.note == null || item.note!.isEmpty
          ? 'Scheduled payment'
          : 'Scheduled · ${item.note}',
      tags: item.tags,
      paymentMode: item.paymentMode,
      accountId: item.accountId,
    );

    final now = _now();
    final paid = item.copyWith(
      status: ScheduleStatus.paid,
      paidAt: now,
      transactionId: tx.id,
      updatedAt: now,
    );
    _items = [..._items]..[i] = paid;
    notifyListeners();
    await _persist();
    await _queueNext(item, paidOn, now);
    return paid;
  }

  Future<ScheduledPayment> skip(String id) async {
    final i = _items.indexWhere((p) => p.id == id);
    if (i < 0) throw StateError('Scheduled payment not found.');
    final item = _items[i];
    if (item.status != ScheduleStatus.pending) {
      throw StateError('Only pending payments can be skipped.');
    }
    final now = _now();
    final skipped = item.copyWith(
      status: ScheduleStatus.skipped,
      updatedAt: now,
    );
    _items = [..._items]..[i] = skipped;
    notifyListeners();
    await _persist();
    await _queueNext(item, item.dueDate, now);
    return skipped;
  }

  /// Soft-delete — keeps row in history.
  Future<ScheduledPayment> cancel(String id) async {
    final i = _items.indexWhere((p) => p.id == id);
    if (i < 0) throw StateError('Scheduled payment not found.');
    final item = _items[i];
    if (item.status == ScheduleStatus.cancelled) return item;
    final now = _now();
    final cancelled = item.copyWith(
      status: ScheduleStatus.cancelled,
      deletedAt: now,
      updatedAt: now,
    );
    _items = [..._items]..[i] = cancelled;
    notifyListeners();
    await _persist();
    return cancelled;
  }

  Future<int> processDue() async {
    final today = scheduleTodayKey();
    final due = [
      for (final p in pending)
        if (p.dueDate.compareTo(today) <= 0) p,
    ];
    var count = 0;
    for (final p in due) {
      try {
        await payNow(p.id);
        count += 1;
      } catch (_) {
        // Leave pending if account/txn fails.
      }
    }
    return count;
  }

  Future<void> _queueNext(
    ScheduledPayment item,
    String fromDue,
    String nowIso,
  ) async {
    final nextDate = nextDueDate(fromDue, item.repeat);
    if (nextDate == null) return;

    // Avoid duplicate pending for same series.
    final exists = _items.any(
      (p) =>
          p.status == ScheduleStatus.pending &&
          p.title == item.title &&
          p.amount == item.amount &&
          p.category == item.category &&
          p.accountId == item.accountId &&
          p.repeat == item.repeat &&
          p.dueDate == nextDate,
    );
    if (exists) return;

    final next = ScheduledPayment(
      id: _newId(),
      title: item.title,
      amount: item.amount,
      category: item.category,
      dueDate: nextDate,
      status: ScheduleStatus.pending,
      repeat: item.repeat,
      accountId: item.accountId,
      paymentMode: item.paymentMode,
      tags: item.tags,
      note: item.note,
      createdAt: nowIso,
      updatedAt: nowIso,
    );
    _items = [..._items, next];
    notifyListeners();
    await _persist();
  }

  Future<void> replaceAll(List<ScheduledPayment> items) async {
    _items = [...items];
    notifyListeners();
    await _persist();
  }
}
