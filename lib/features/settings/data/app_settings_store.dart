// Persisted app settings (tags, income, cycle, next-cycle draft, add defaults).

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/storage/local_storage.dart';
import '../../accounts/domain/payments.dart';
import '../../activity/domain/cycle.dart';
import '../../budgets/data/next_cycle_budget.dart';
import 'app_settings.dart';

class AppSettingsStore extends ChangeNotifier {
  AppSettingsStore();

  static final AppSettingsStore instance = AppSettingsStore();

  AppSettings _settings = const AppSettings();

  AppSettings get settings => _settings;
  List<String> get tags => _settings.tags;
  double get monthlyIncome => _settings.monthlyIncome;
  int get cycleStartDay => _settings.cycleStartDay;
  NextCycleBudget? get nextCycleBudget => _settings.nextCycleBudget;
  String? get activeCycleStart => _settings.activeCycleStart;
  String get defaultCategory => _settings.defaultCategory;
  String? get defaultTag => _settings.defaultTag;
  DefaultDateMode get defaultDateMode => _settings.defaultDateMode;
  String? get lastTransactionDate => _settings.lastTransactionDate;
  String? get defaultAccountId => _settings.defaultAccountId;
  PaymentMode get defaultPaymentMode => _settings.defaultPaymentMode;
  double get lowBalanceThreshold => _settings.lowBalanceThreshold;
  bool get lowBalanceEnabled => _settings.lowBalanceEnabled;
  bool get notificationsEnabled => _settings.notificationsEnabled;
  bool get dailyLogReminderEnabled => _settings.dailyLogReminderEnabled;
  int get dailyLogReminderHour => _settings.dailyLogReminderHour;
  int get dailyLogReminderMinute => _settings.dailyLogReminderMinute;
  bool get budgetRemindersEnabled => _settings.budgetRemindersEnabled;
  bool get scheduledRemindersEnabled => _settings.scheduledRemindersEnabled;
  bool get debtRemindersEnabled => _settings.debtRemindersEnabled;
  int get debtReminderLeadDays => _settings.debtReminderLeadDays;
  int get scheduledReminderLeadDays => _settings.scheduledReminderLeadDays;
  bool get plannedReservesEnabled => _settings.plannedReservesEnabled;
  PlannedReserveAllocationMode get plannedReserveAllocationMode =>
      _settings.plannedReserveAllocationMode;

  void load() {
    final raw = LocalStorage.getString(AppConstants.appSettingsKey);
    if (raw == null || raw.isEmpty) {
      _settings = const AppSettings();
      return;
    }
    try {
      final parsed = AppSettings.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
      _settings = parsed.copyWith(
        cycleStartDay: clampCycleStartDay(parsed.cycleStartDay),
      );
    } catch (_) {
      _settings = const AppSettings();
    }
  }

  Future<void> _persist() async {
    await LocalStorage.setString(
      AppConstants.appSettingsKey,
      jsonEncode(_settings.toJson()),
    );
  }

  Future<void> replace(AppSettings settings) async {
    _settings = settings.copyWith(
      cycleStartDay: clampCycleStartDay(settings.cycleStartDay),
    );
    notifyListeners();
    await _persist();
  }

  Future<void> setMonthlyIncome(double value) async {
    final next = value.isFinite && value >= 0 ? value : 0.0;
    if (_settings.monthlyIncome == next) return;
    _settings = _settings.copyWith(monthlyIncome: next);
    notifyListeners();
    await _persist();
  }

  Future<void> setCycleStartDay(int day) async {
    final next = clampCycleStartDay(day);
    if (_settings.cycleStartDay == next) return;
    _settings = _settings.copyWith(cycleStartDay: next);
    notifyListeners();
    await _persist();
  }

  Future<void> setNextCycleBudget(NextCycleBudget? draft) async {
    _settings = draft == null
        ? _settings.copyWith(clearNextCycleBudget: true)
        : _settings.copyWith(nextCycleBudget: draft);
    notifyListeners();
    await _persist();
  }

  Future<void> setDefaultCategory(String category) async {
    final next = category.trim().isEmpty ? 'Food' : category.trim();
    if (_settings.defaultCategory == next) return;
    _settings = _settings.copyWith(defaultCategory: next);
    notifyListeners();
    await _persist();
  }

  Future<void> setDefaultTag(String? tag) async {
    if (tag == null || tag.trim().isEmpty) {
      if (_settings.defaultTag == null) return;
      _settings = _settings.copyWith(clearDefaultTag: true);
      notifyListeners();
      await _persist();
      return;
    }
    final trimmed = tag.trim();
    String? match;
    for (final t in _settings.tags) {
      if (t.toLowerCase() == trimmed.toLowerCase()) {
        match = t;
        break;
      }
    }
    if (match == null) return;
    if (_settings.defaultTag == match) return;
    _settings = _settings.copyWith(defaultTag: match);
    notifyListeners();
    await _persist();
  }

  Future<void> setDefaultDateMode(DefaultDateMode mode) async {
    if (_settings.defaultDateMode == mode) return;
    _settings = _settings.copyWith(defaultDateMode: mode);
    notifyListeners();
    await _persist();
  }

  Future<void> setLastTransactionDate(String dayKey) async {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dayKey)) return;
    if (_settings.lastTransactionDate == dayKey) return;
    _settings = _settings.copyWith(lastTransactionDate: dayKey);
    notifyListeners();
    await _persist();
  }

  Future<void> setDefaultAccountId(String? id) async {
    if (id == null || id.isEmpty) {
      if (_settings.defaultAccountId == null) return;
      _settings = _settings.copyWith(clearDefaultAccountId: true);
      notifyListeners();
      await _persist();
      return;
    }
    if (_settings.defaultAccountId == id) return;
    _settings = _settings.copyWith(defaultAccountId: id);
    notifyListeners();
    await _persist();
  }

  Future<void> setDefaultPaymentMode(PaymentMode mode) async {
    if (_settings.defaultPaymentMode == mode) return;
    _settings = _settings.copyWith(defaultPaymentMode: mode);
    notifyListeners();
    await _persist();
  }

  Future<void> setLowBalanceEnabled(bool enabled) async {
    if (_settings.lowBalanceEnabled == enabled) return;
    _settings = _settings.copyWith(lowBalanceEnabled: enabled);
    notifyListeners();
    await _persist();
  }

  Future<void> setLowBalanceThreshold(double value) async {
    final next = value.isFinite && value >= 0 ? value : 0.0;
    if (_settings.lowBalanceThreshold == next) return;
    _settings = _settings.copyWith(lowBalanceThreshold: next);
    notifyListeners();
    await _persist();
  }

  Future<void> setNotificationsEnabled(bool value) async {
    if (_settings.notificationsEnabled == value) return;
    _settings = _settings.copyWith(notificationsEnabled: value);
    notifyListeners();
    await _persist();
  }

  Future<void> setDailyLogReminderEnabled(bool value) async {
    if (_settings.dailyLogReminderEnabled == value) return;
    _settings = _settings.copyWith(dailyLogReminderEnabled: value);
    notifyListeners();
    await _persist();
  }

  Future<void> setDailyLogReminderTime(int hour, int minute) async {
    final h = hour.clamp(0, 23);
    final m = minute.clamp(0, 59);
    if (_settings.dailyLogReminderHour == h &&
        _settings.dailyLogReminderMinute == m) {
      return;
    }
    _settings = _settings.copyWith(
      dailyLogReminderHour: h,
      dailyLogReminderMinute: m,
    );
    notifyListeners();
    await _persist();
  }

  Future<void> setBudgetRemindersEnabled(bool value) async {
    if (_settings.budgetRemindersEnabled == value) return;
    _settings = _settings.copyWith(budgetRemindersEnabled: value);
    notifyListeners();
    await _persist();
  }

  Future<void> setScheduledRemindersEnabled(bool value) async {
    if (_settings.scheduledRemindersEnabled == value) return;
    _settings = _settings.copyWith(scheduledRemindersEnabled: value);
    notifyListeners();
    await _persist();
  }

  Future<void> setDebtRemindersEnabled(bool value) async {
    if (_settings.debtRemindersEnabled == value) return;
    _settings = _settings.copyWith(debtRemindersEnabled: value);
    notifyListeners();
    await _persist();
  }

  Future<void> setDebtReminderLeadDays(int days) async {
    final next = days.clamp(1, 14);
    if (_settings.debtReminderLeadDays == next) return;
    _settings = _settings.copyWith(debtReminderLeadDays: next);
    notifyListeners();
    await _persist();
  }

  Future<void> setScheduledReminderLeadDays(int days) async {
    final next = days.clamp(1, 14);
    if (_settings.scheduledReminderLeadDays == next) return;
    _settings = _settings.copyWith(scheduledReminderLeadDays: next);
    notifyListeners();
    await _persist();
  }

  Future<void> setPlannedReservesEnabled(bool value) async {
    if (_settings.plannedReservesEnabled == value) return;
    _settings = _settings.copyWith(plannedReservesEnabled: value);
    notifyListeners();
    await _persist();
  }

  Future<void> setPlannedReserveAllocationMode(
    PlannedReserveAllocationMode mode,
  ) async {
    if (_settings.plannedReserveAllocationMode == mode) return;
    _settings = _settings.copyWith(plannedReserveAllocationMode: mode);
    notifyListeners();
    await _persist();
  }

  /// Date to pre-fill on add-transaction (YYYY-MM-DD local).
  String resolveDefaultTransactionDate([DateTime? now]) {
    if (_settings.defaultDateMode == DefaultDateMode.remember) {
      final last = _settings.lastTransactionDate;
      if (last != null && last.isNotEmpty) return last;
    }
    final d = now ?? DateTime.now();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  /// Returns true if the tag exists or was created.
  Future<bool> addTag(String tag) async {
    var trimmed = tag.trim();
    while (trimmed.startsWith('#')) {
      trimmed = trimmed.substring(1).trim();
    }
    if (trimmed.isEmpty) return false;
    final exists = _settings.tags.any(
      (t) => t.toLowerCase() == trimmed.toLowerCase(),
    );
    if (exists) return true;
    _settings = _settings.copyWith(tags: [..._settings.tags, trimmed]);
    notifyListeners();
    await _persist();
    return true;
  }

  Future<void> removeTag(String tag) async {
    final clearDefault = _settings.defaultTag != null &&
        _settings.defaultTag!.toLowerCase() == tag.toLowerCase();
    _settings = _settings.copyWith(
      tags: [for (final t in _settings.tags) if (t != tag) t],
      clearDefaultTag: clearDefault,
    );
    notifyListeners();
    await _persist();
  }
}
