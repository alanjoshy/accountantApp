// Persisted app settings (tags, income, cycle, next-cycle draft).

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/storage/local_storage.dart';
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

  Future<void> addTag(String tag) async {
    final trimmed = tag.trim();
    if (trimmed.isEmpty) return;
    final exists = _settings.tags.any(
      (t) => t.toLowerCase() == trimmed.toLowerCase(),
    );
    if (exists) return;
    _settings = _settings.copyWith(tags: [..._settings.tags, trimmed]);
    notifyListeners();
    await _persist();
  }

  Future<void> removeTag(String tag) async {
    _settings = _settings.copyWith(
      tags: [for (final t in _settings.tags) if (t != tag) t],
    );
    notifyListeners();
    await _persist();
  }
}
