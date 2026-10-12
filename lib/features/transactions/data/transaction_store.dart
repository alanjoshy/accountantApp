// Persisted transactions (web useTransactions / Dexie).

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/storage/local_storage.dart';
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

  void _sort() {
    _items.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      if (byDate != 0) return byDate;
      return b.createdAt.compareTo(a.createdAt);
    });
  }

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  String _now() => DateTime.now().toUtc().toIso8601String();

  Future<MoneyTransaction> add({
    required String title,
    required double amount,
    required TransactionType type,
    required String category,
    required String date,
    String? note,
    List<String> tags = const [],
  }) async {
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
    );
    _items = [tx, ..._items];
    _sort();
    notifyListeners();
    await _persist();
    return tx;
  }

  Future<void> update(MoneyTransaction tx) async {
    final i = _items.indexWhere((t) => t.id == tx.id);
    if (i < 0) throw StateError('Transaction not found');
    _items = [..._items]..[i] = tx;
    _sort();
    notifyListeners();
    await _persist();
  }

  Future<void> delete(String id) async {
    _items = [for (final t in _items) if (t.id != id) t];
    notifyListeners();
    await _persist();
  }

  Future<int> deleteMany(Iterable<String> ids) async {
    final set = ids.toSet();
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
