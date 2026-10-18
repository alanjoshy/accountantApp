// Persisted budgets + cycle sync.

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/storage/local_storage.dart';
import '../../settings/data/app_settings_store.dart';
import '../domain/budget_cycle.dart';
import 'budget.dart';
import 'category_style.dart';

/// Default category shells (web DEFAULT_BUDGET_CATEGORIES) — limits start at 0.
const defaultBudgetCategories = <String>[
  'Food',
  'Grocery',
  'Transport',
  'Bills',
  'Shopping',
  'Entertainment',
  'Health',
  'Other',
];

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

  /// Seed empty category rows once so income can be allocated (web parity).
  Future<void> ensureDefaultCategories() async {
    final seeded =
        LocalStorage.getString(AppConstants.budgetsSeededKey) == '1';
    if (seeded) return;
    if (_items.isNotEmpty) {
      await LocalStorage.setString(AppConstants.budgetsSeededKey, '1');
      return;
    }
    final now = DateTime.now().toUtc().toIso8601String();
    _items = [
      for (var i = 0; i < defaultBudgetCategories.length; i++)
        Budget(
          id: _newId(),
          category: defaultBudgetCategories[i],
          limit: 0,
          icon: defaultIconForCategory(defaultBudgetCategories[i]),
          color: defaultColorForCategory(defaultBudgetCategories[i], i),
          createdAt: now,
        ),
    ];
    notifyListeners();
    await _persist();
    await LocalStorage.setString(AppConstants.budgetsSeededKey, '1');
  }

  Future<void> _persist() async {
    await LocalStorage.setString(
      AppConstants.budgetsKey,
      jsonEncode(_items.map((b) => b.toJson()).toList()),
    );
  }

  int _idSeq = 0;

  String _newId() {
    _idSeq += 1;
    return '${DateTime.now().microsecondsSinceEpoch}-$_idSeq';
  }

  Future<void> replaceAll(List<Budget> items) async {
    _items = items;
    notifyListeners();
    await _persist();
  }

  /// One-time: drop cycle/custom dates so categories stay until deleted.
  Future<void> migrateToPermanentCategories() async {
    if (LocalStorage.getString(AppConstants.budgetsPermanentKey) == '1') {
      // Still backfill icon/color for older rows.
      await _backfillStyles();
      return;
    }
    if (_items.any((b) => b.hasCustomRange)) {
      _items = [
        for (final b in _items) b.copyWith(clearDates: true),
      ];
      notifyListeners();
      await _persist();
    }
    await LocalStorage.setString(AppConstants.budgetsPermanentKey, '1');
    await _backfillStyles();
  }

  Future<void> _backfillStyles() async {
    var changed = false;
    final next = <Budget>[];
    for (var i = 0; i < _items.length; i++) {
      final b = _items[i];
      final needsIcon = b.icon.isEmpty || b.icon == 'more';
      final needsColor = b.color.isEmpty || b.color == '#3b82f6';
      if (!needsIcon && !needsColor) {
        next.add(b);
        continue;
      }
      changed = true;
      next.add(
        b.copyWith(
          icon: needsIcon ? defaultIconForCategory(b.category) : b.icon,
          color: needsColor
              ? defaultColorForCategory(b.category, i)
              : b.color,
        ),
      );
    }
    if (!changed) return;
    _items = next;
    notifyListeners();
    await _persist();
  }

  /// Activate next draft if due, then rollover dated rows.
  /// Permanent (undated) categories are left alone until deleted.
  Future<void> syncCycles() async {
    await migrateToPermanentCategories();
    final settingsStore = AppSettingsStore.instance;
    var settings = settingsStore.settings;
    var budgets = _items;

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
    String? icon,
    String? color,
  }) async {
    final start = startDate?.trim();
    final end = endDate?.trim();
    final name = category.trim();
    final budget = Budget(
      id: _newId(),
      category: name,
      limit: limit < 0 ? 0 : limit,
      startDate: start == null || start.isEmpty ? null : start,
      endDate: end == null || end.isEmpty ? null : end,
      icon: icon ?? defaultIconForCategory(name),
      color: color ?? defaultColorForCategory(name, _items.length),
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
