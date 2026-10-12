// Persisted budgets + cycle sync.

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/storage/local_storage.dart';
import '../../activity/domain/cycle.dart';
import '../../settings/data/app_settings_store.dart';
import '../domain/budget_cycle.dart';
import '../domain/budget_logic.dart';
import 'budget.dart';

class BudgetStore extends ChangeNotifier {
  BudgetStore();

  static final BudgetStore instance = BudgetStore();

  List<Budget> _items = const [];

  List<Budget> get budgets => _items;

  void load() {
    final raw = LocalStorage.getString(AppConstants.budgetsKey);
    if (raw == null || raw.isEmpty) {
      _items = const [];
      return;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      _items = [
        for (final item in list)
          Budget.fromJson(Map<String, dynamic>.from(item as Map)),
      ];
    } catch (_) {
      _items = const [];
    }
  }

  Future<void> _persist() async {
    await LocalStorage.setString(
      AppConstants.budgetsKey,
      jsonEncode(_items.map((b) => b.toJson()).toList()),
    );
  }

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<void> replaceAll(List<Budget> items) async {
    _items = items;
    notifyListeners();
    await _persist();
  }

  /// Stamp undated rows, activate next draft if due, then rollover.
  Future<void> syncCycles() async {
    final settingsStore = AppSettingsStore.instance;
    var settings = settingsStore.settings;
    var budgets = _items;

    if (budgets.any((b) => !hasCustomBudgetRange(b))) {
      budgets = stampUndatedBudgets(budgets, settings.cycleStartDay);
    }

    final activated = activateNextCycleIfDue(
      settings: settings,
      budgets: budgets,
    );
    budgets = activated.budgets;
    settings = activated.settings;

    final rolled = rolloverCycleBudgets(
      settings: settings,
      budgets: budgets,
    );
    budgets = rolled.budgets;
    settings = rolled.settings;

    final budgetsChanged = budgets != _items;
    if (budgetsChanged) {
      _items = budgets;
      notifyListeners();
      await _persist();
    }
    if (settings != settingsStore.settings) {
      await settingsStore.replace(settings);
    }
  }

  Future<Budget> add({
    required String category,
    required double limit,
    String? startDate,
    String? endDate,
  }) async {
    var start = startDate?.trim();
    var end = endDate?.trim();
    if (start == null || start.isEmpty || end == null || end.isEmpty) {
      final cycle = getCurrentCycleDayBounds(
        AppSettingsStore.instance.cycleStartDay,
      );
      start = cycle.start;
      end = cycle.end;
    }
    final budget = Budget(
      id: _newId(),
      category: category.trim(),
      limit: limit < 0 ? 0 : limit,
      startDate: start,
      endDate: end,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
    _items = [..._items, budget];
    notifyListeners();
    await _persist();
    return budget;
  }

  Future<void> update(Budget budget) async {
    final i = _items.indexWhere((b) => b.id == budget.id);
    if (i < 0) throw StateError('Budget not found');
    _items = [..._items]..[i] = budget;
    notifyListeners();
    await _persist();
  }

  Future<void> updateLimits(List<({String id, double limit})> rows) async {
    if (rows.isEmpty) return;
    final map = {for (final r in rows) r.id: r.limit < 0 ? 0.0 : r.limit};
    _items = [
      for (final b in _items)
        if (map.containsKey(b.id)) b.copyWith(limit: map[b.id]) else b,
    ];
    notifyListeners();
    await _persist();
  }

  Future<void> delete(String id) async {
    _items = [for (final b in _items) if (b.id != id) b];
    notifyListeners();
    await _persist();
  }
}
