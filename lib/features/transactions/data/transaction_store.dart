// Persisted transactions (web useTransactions / Dexie).

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/storage/local_storage.dart';
import '../../accounts/data/account_store.dart';
import '../../accounts/domain/account_balances.dart';
import '../../accounts/domain/payments.dart';
import '../../settings/data/app_settings_store.dart';
import 'transaction.dart';

class TransactionStore extends ChangeNotifier {
  TransactionStore();

  static final TransactionStore instance = TransactionStore();

  List<MoneyTransaction> _items = const [];

  List<MoneyTransaction> get transactions => _items;

  int get count => _items.length;

  int get incomeEntryCount =>
      _items.where((t) => t.type == TransactionType.income).length;

  void load() {
    final raw = LocalStorage.getString(AppConstants.transactionsKey);
    if (raw == null || raw.isEmpty) {
      _items = const [];
      return;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      _items = [
        for (final item in list)
          MoneyTransaction.fromJson(Map<String, dynamic>.from(item as Map)),
      ];
      _sort();
    } catch (_) {
      _items = const [];
    }
  }

  Future<void> _persist() async {
    final encoded = jsonEncode(_items.map((t) => t.toJson()).toList());
    await LocalStorage.setString(AppConstants.transactionsKey, encoded);
  }

  /// Replace all rows without re-applying account deltas (backup restore).
  Future<void> replaceAll(List<MoneyTransaction> items) async {
    _items = [...items];
    _sort();
    notifyListeners();
    await _persist();
  }

  void _sort() {
    _items.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      if (byDate != 0) return byDate;
      return b.createdAt.compareTo(a.createdAt);
    });
  }

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  String _now() => DateTime.now().toUtc().toIso8601String();

  Future<void> _syncAccounts(MoneyTransaction t, {required bool reverse}) async {
    // Transfers must not overdraw; income/expense may go negative until tally.
    final strictTransfer = t.type == TransactionType.transfer &&
        t.category != 'Adjustment';
    final next = applyTransactionToAccounts(
      AccountStore.instance.accounts,
      t,
      reverse: reverse,
      allowNegative: !strictTransfer,
    );
    await AccountStore.instance.applyBalances(next);
  }

  /// Prefer an explicit account; otherwise the default / first account so
  /// home "Account balance" stays in sync with income & expense.
  String? _resolveAccountId(String? accountId) {
    final accounts = AccountStore.instance.accounts;
    if (accounts.isEmpty) return null;
    bool exists(String? id) =>
        id != null && id.isNotEmpty && accounts.any((a) => a.id == id);
    if (exists(accountId)) return accountId;
    final preferred = AppSettingsStore.instance.defaultAccountId;
    if (exists(preferred)) return preferred;
    return accounts.first.id;
  }

  Future<MoneyTransaction> add({
    required String title,
    required double amount,
    required TransactionType type,
    required String category,
    required String date,
    String? note,
    List<String> tags = const [],
    PaymentMode? paymentMode,
    String? accountId,
    String? toAccountId,
  }) async {
    final resolvedAccountId = type == TransactionType.transfer
        ? accountId
        : _resolveAccountId(accountId);
    final tx = MoneyTransaction(
      id: _newId(),
      title: title.trim(),
      amount: amount.abs(),
      type: type,
      category: category.trim(),
      date: date,
      createdAt: _now(),
      note: note?.trim().isEmpty ?? true ? null : note!.trim(),
      tags: tags,
      paymentMode: paymentMode,
      accountId: resolvedAccountId,
      toAccountId: toAccountId,
    );
    await _syncAccounts(tx, reverse: false);
    _items = [tx, ..._items];
    _sort();
    notifyListeners();
    await _persist();
    return tx;
  }

  Future<void> update(MoneyTransaction tx) async {
    final i = _items.indexWhere((t) => t.id == tx.id);
    if (i < 0) throw StateError('Transaction not found');
    final previous = _items[i];
    await _syncAccounts(previous, reverse: true);
    try {
      await _syncAccounts(tx, reverse: false);
    } catch (e) {
      await _syncAccounts(previous, reverse: false);
      rethrow;
    }
    _items = [..._items]..[i] = tx;
    _sort();
    notifyListeners();
    await _persist();
  }

  Future<void> delete(String id) async {
    final existing = _items.where((t) => t.id == id).firstOrNull;
    if (existing != null) {
      await _syncAccounts(existing, reverse: true);
    }
    _items = [for (final t in _items) if (t.id != id) t];
    notifyListeners();
    await _persist();
  }

  Future<int> deleteMany(Iterable<String> ids) async {
    final set = ids.toSet();
    final removing = [for (final t in _items) if (set.contains(t.id)) t];
    for (final t in removing) {
      await _syncAccounts(t, reverse: true);
    }
    final before = _items.length;
    _items = [for (final t in _items) if (!set.contains(t.id)) t];
    final removed = before - _items.length;
    if (removed > 0) {
      notifyListeners();
      await _persist();
    }
    return removed;
  }
}
