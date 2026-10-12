// Persisted savings jars (web useJars / Dexie jars).

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/storage/local_storage.dart';
import 'jar_goal.dart';

class JarStore extends ChangeNotifier {
  JarStore();

  static final JarStore instance = JarStore();

  List<JarGoal> _jars = const [];

  List<JarGoal> get jars => _jars;

  void load() {
    final raw = LocalStorage.getString(AppConstants.jarsKey);
    if (raw == null || raw.isEmpty) {
      _jars = const [];
      return;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      _jars = [
        for (final item in list)
          JarGoal.fromJson(Map<String, dynamic>.from(item as Map)),
      ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (_) {
      _jars = const [];
    }
  }

  Future<void> _persist() async {
    final encoded = jsonEncode(_jars.map((j) => j.toJson()).toList());
    await LocalStorage.setString(AppConstants.jarsKey, encoded);
  }

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  String _now() => DateTime.now().toUtc().toIso8601String();

  Future<JarGoal> createJar({
    required String name,
    required double targetAmount,
    double currentAmount = 0,
    required String color,
  }) async {
    final now = _now();
    final jar = JarGoal(
      id: _newId(),
      name: name.trim(),
      targetAmount: targetAmount,
      currentAmount: currentAmount < 0 ? 0 : currentAmount,
      color: color,
      icon: 'jar',
      createdAt: now,
      updatedAt: now,
    );
    _jars = [jar, ..._jars];
    notifyListeners();
    await _persist();
    return jar;
  }

  Future<void> updateJar(
    String id, {
    String? name,
    double? targetAmount,
    double? currentAmount,
    String? color,
  }) async {
    final i = _jars.indexWhere((j) => j.id == id);
    if (i < 0) throw StateError('Jar not found');
    final next = _jars[i].copyWith(
      name: name?.trim(),
      targetAmount: targetAmount,
      currentAmount: currentAmount == null
          ? null
          : (currentAmount < 0 ? 0 : currentAmount),
      color: color,
      updatedAt: _now(),
    );
    _jars = [..._jars]..[i] = next;
    _jars.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    notifyListeners();
    await _persist();
  }

  Future<void> addMoney(String id, double amount) async {
    if (amount == 0) throw ArgumentError('Amount must be non-zero');
    final i = _jars.indexWhere((j) => j.id == id);
    if (i < 0) throw StateError('Jar not found');
    final existing = _jars[i];
    final nextAmount = (existing.currentAmount + amount).clamp(0.0, double.infinity);
    final next = existing.copyWith(
      currentAmount: nextAmount,
      updatedAt: _now(),
      updates: [
        ...existing.updates,
        JarUpdate(amount: amount, at: _now()),
      ],
    );
    _jars = [..._jars]..[i] = next;
    _jars.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    notifyListeners();
    await _persist();
  }

  Future<void> deleteJar(String id) async {
    _jars = [for (final j in _jars) if (j.id != id) j];
    notifyListeners();
    await _persist();
  }
}
