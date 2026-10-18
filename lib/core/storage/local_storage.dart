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

  static String? getString(String key) => _p.getString(key);

  static Future<bool> setString(String key, String value) =>
      _p.setString(key, value);

  static Future<bool> remove(String key) => _p.remove(key);

  static bool? getBool(String key) => _p.getBool(key);

  static Future<bool> setBool(String key, bool value) => _p.setBool(key, value);
}
