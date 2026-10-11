// Persisted theme preference (web AppearanceSettings).

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/storage/local_storage.dart';

class ThemeController extends ChangeNotifier {
  ThemeController._();

  static final ThemeController instance = ThemeController._();

  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  void load() {
    _mode = _decode(LocalStorage.getString(AppConstants.themeModeKey));
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    await LocalStorage.setString(AppConstants.themeModeKey, _encode(mode));
  }

  static ThemeMode _decode(String? raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _encode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}
