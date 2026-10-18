// Persisted lend / borrow entries.

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/storage/local_storage.dart';
import '../domain/debt_logic.dart';
import 'debt.dart';

class DebtStore extends ChangeNotifier {
  DebtStore();

  static final DebtStore instance = DebtStore();

  List<Debt> _items = const [];

  List<Debt> get debts => _items;

  List<Debt> get open => [
        for (final d in _items)
          if (d.status == DebtStatus.open) d,
      ];

  List<Debt> get settled => [
        for (final d in _items)
          if (d.status == DebtStatus.collected) d,
      ];

  List<Debt> get openLend => [
        for (final d in open)
          if (debtKind(d) == DebtKind.lend) d,
      ];

  List<Debt> get openBorrow => [
        for (final d in open)
          if (debtKind(d) == DebtKind.borrow) d,
      ];

  void load() {
    final raw = LocalStorage.getString(AppConstants.debtsKey);
    if (raw == null || raw.isEmpty) {
      _items = const [];
      return;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      _items = [
        for (final item in list)
          Debt.fromJson(Map<String, dynamic>.from(item as Map)),
      ]..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    } catch (_) {
      _items = const [];
    }
  }

  Future<void> _persist() async {
    await LocalStorage.setString(
      AppConstants.debtsKey,
      jsonEncode(_items.map((d) => d.toJson()).toList()),
    );
  }

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  String _now() => DateTime.now().toUtc().toIso8601String();

  Future<Debt> addDebt({
    required String personName,
    required double amount,
    required String lentDate,
    required String dueDate,
    required DebtKind kind,
    String? note,
  }) async {
    final now = _now();
    final debt = Debt(
      id: _newId(),
      personName: personName.trim(),
      amount: amount,
      amountPaid: 0,
      lentDate: lentDate.isEmpty ? todayKey() : lentDate,
      dueDate: dueDate,
      kind: kind,
      status: DebtStatus.open,
      note: note?.trim().isEmpty == true ? null : note?.trim(),
      createdAt: now,
      updatedAt: now,
    );
    _items = [..._items, debt]..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    notifyListeners();
    await _persist();
    return debt;
  }

  Future<Debt> recordPayment(String id, double payment) async {
    final i = _items.indexWhere((d) => d.id == id);
    if (i < 0) throw StateError('Entry not found.');
    final debt = _items[i];
    if (debt.status != DebtStatus.open) {
      throw StateError('This entry is already settled.');
    }
    final remaining = debtRemaining(debt);
    if (!(payment > 0)) {
      throw ArgumentError('Enter an amount greater than zero.');
    }
    if (payment > remaining + 0.000001) {
      throw ArgumentError(
        "Amount can't be more than the remaining ${remaining.toStringAsFixed(2)}.",
      );
    }
    final nextPaid = (debtPaid(debt) + payment).clamp(0.0, debt.amount);
    final settled = nextPaid >= debt.amount - 0.000001;
    final next = debt.copyWith(
      amountPaid: settled ? debt.amount : nextPaid,
      status: settled ? DebtStatus.collected : DebtStatus.open,
      updatedAt: _now(),
    );
    _items = [..._items]..[i] = next;
    _items.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    notifyListeners();
    await _persist();
    return next;
  }

  Future<void> markSettled(String id) async {
    final i = _items.indexWhere((d) => d.id == id);
    if (i < 0) throw StateError('Entry not found.');
    final debt = _items[i];
    _items = [..._items]
      ..[i] = debt.copyWith(
        amountPaid: debt.amount,
        status: DebtStatus.collected,
        updatedAt: _now(),
      );
    notifyListeners();
    await _persist();
  }

  Future<void> deleteDebt(String id) async {
    _items = [for (final d in _items) if (d.id != id) d];
    notifyListeners();
    await _persist();
  }

  Future<void> replaceAll(List<Debt> items) async {
    _items = [...items]..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    notifyListeners();
    await _persist();
  }
}
