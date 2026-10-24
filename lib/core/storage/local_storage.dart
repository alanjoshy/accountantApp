// SharedPreferences wrapper.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  LocalStorage._();

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Drop the cached handle so the next [init] picks up a fresh instance
  /// (needed after [SharedPreferences.setMockInitialValues] in tests).
  @visibleForTesting
  static void resetForTest() {
    _prefs = null;
  }

  static SharedPreferences get _p {
    final prefs = _prefs;
    if (prefs == null) {
      throw StateError('LocalStorage.init() was not called');
    }
    return prefs;
  }

  static String? getString(String key) {
    try {
      return _p.getString(key);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> setString(String key, String value) =>
      _p.setString(key, value);

  static Future<bool> remove(String key) => _p.remove(key);

  /// Removes each key that exists. Ignores missing keys.
  static Future<void> removeAll(Iterable<String> keys) async {
    for (final key in keys) {
      await _p.remove(key);
    }
  }

  /// Reads a bool, also accepting legacy string flags (`'1'` / `'true'`).
  static bool? getBool(String key) {
    try {
      return _p.getBool(key);
    } catch (_) {
      try {
        final raw = _p.getString(key);
        if (raw == null) return null;
        final normalized = raw.trim().toLowerCase();
        if (normalized == '1' || normalized == 'true') return true;
        if (normalized == '0' || normalized == 'false') return false;
      } catch (_) {}
      return null;
    }
  }

  static Future<bool> setBool(String key, bool value) => _p.setBool(key, value);
}
