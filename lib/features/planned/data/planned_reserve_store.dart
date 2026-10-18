// Persisted planned budget reserves.

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/storage/local_storage.dart';
import 'planned_reserve.dart';

class PlannedReserveStore extends ChangeNotifier {
  PlannedReserveStore();

  static final PlannedReserveStore instance = PlannedReserveStore();

  List<PlannedReserve> _items = const [];

  List<PlannedReserve> get all => _items;

  List<PlannedReserve> get active => [
        for (final r in _items)
          if (r.isActive) r,
      ]..sort((a, b) => a.dueDate.compareTo(b.dueDate));

  List<PlannedReserve> get archived => [
        for (final r in _items)
          if (!r.isActive) r,
      ]..sort((a, b) => (b.deletedAt ?? b.updatedAt)
          .compareTo(a.deletedAt ?? a.updatedAt));

  void load() {
    final raw = LocalStorage.getString(AppConstants.plannedReservesKey);
    if (raw == null || raw.isEmpty) {
      _items = const [];
      return;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      _items = [
        for (final item in list)
          PlannedReserve.fromJson(Map<String, dynamic>.from(item as Map)),
      ];
    } catch (_) {
      _items = const [];
    }
  }

  Future<void> _persist() async {
    await LocalStorage.setString(
      AppConstants.plannedReservesKey,
      jsonEncode(_items.map((r) => r.toJson()).toList()),
    );
  }

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  String _now() => DateTime.now().toUtc().toIso8601String();

  Future<PlannedReserve> add({
    required String title,
    required double amount,
    required String category,
    required String dueDate,
    String? note,
  }) async {
    final at = _now();
    final item = PlannedReserve(
      id: _newId(),
      title: title.trim(),
      amount: amount.abs(),
      category: category.trim(),
      dueDate: dueDate,
      note: note?.trim().isEmpty ?? true ? null : note!.trim(),
      createdAt: at,
      updatedAt: at,
    );
    _items = [item, ..._items];
    notifyListeners();
    await _persist();
    return item;
  }

  Future<void> update(PlannedReserve item) async {
    final i = _items.indexWhere((r) => r.id == item.id);
    if (i < 0) throw StateError('Planned reserve not found');
    _items = [..._items]..[i] = item.copyWith(updatedAt: _now());
    notifyListeners();
    await _persist();
  }

  Future<void> softDelete(String id) async {
    final i = _items.indexWhere((r) => r.id == id);
    if (i < 0) return;
    final at = _now();
    _items = [..._items]
      ..[i] = _items[i].copyWith(deletedAt: at, updatedAt: at);
    notifyListeners();
    await _persist();
  }

  Future<void> markApplied(Iterable<String> ids, String cycleStart) async {
    final set = ids.toSet();
    if (set.isEmpty) return;
    final at = _now();
    var changed = false;
    final next = <PlannedReserve>[];
    for (final r in _items) {
      if (set.contains(r.id)) {
        changed = true;
        next.add(r.copyWith(appliedCycleStart: cycleStart, updatedAt: at));
      } else {
        next.add(r);
      }
    }
    if (!changed) return;
    _items = next;
    notifyListeners();
    await _persist();
  }

  Future<void> replaceAll(List<PlannedReserve> next) async {
    _items = next;
    notifyListeners();
    await _persist();
  }
}
