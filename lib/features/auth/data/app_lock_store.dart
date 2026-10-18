// Persisted app-lock PIN + security preferences.

import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/storage/local_storage.dart';
import '../domain/pin_crypto.dart';

class AppLockStore extends ChangeNotifier {
  AppLockStore._();
  static final instance = AppLockStore._();

  /// Force a PIN entry at least this often even when biometrics are on.
  static const weeklyPinInterval = Duration(days: 7);

  String? get pinHash => LocalStorage.getString(AppConstants.pinHashKey);

  bool get hasPin => pinHash != null && pinHash!.isNotEmpty;

  bool get isEnabled =>
      LocalStorage.getBool(AppConstants.lockEnabledKey) ?? hasPin;

  bool get biometricEnabled =>
      LocalStorage.getBool(AppConstants.biometricEnabledKey) ?? false;

  bool get lockOnResume =>
      LocalStorage.getBool(AppConstants.lockOnResumeKey) ?? true;

  bool get protectAccountBalances =>
      LocalStorage.getBool(AppConstants.protectAccountBalancesKey) ?? false;

  /// When on (default), PIN is required at least once every 7 days.
  bool get weeklyPinEnabled =>
      LocalStorage.getBool(AppConstants.weeklyPinEnabledKey) ?? true;

  DateTime? get lastPinUnlockAt {
    final raw = LocalStorage.getString(AppConstants.lastPinUnlockAtKey);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  /// Cold start / resume should show the lock gate.
  bool get shouldShowLock => isEnabled && hasPin;

  /// True when biometrics must not unlock — user needs to enter PIN.
  bool requiresWeeklyPin([DateTime? now]) {
    if (!weeklyPinEnabled || !hasPin || !isEnabled) return false;
    final last = lastPinUnlockAt;
    if (last == null) return true;
    final ref = now ?? DateTime.now();
    return ref.difference(last) >= weeklyPinInterval;
  }

  /// Biometrics may unlock the app right now.
  bool get canUseBiometricUnlock =>
      biometricEnabled && isEnabled && hasPin && !requiresWeeklyPin();

  Future<void> setPin(String pin) async {
    final hashed = PinCrypto.hash(pin);
    await LocalStorage.setString(AppConstants.pinHashKey, hashed);
    await LocalStorage.setBool(AppConstants.lockEnabledKey, true);
    await markPinUnlock();
    notifyListeners();
  }

  bool verify(String pin) {
    final stored = pinHash;
    if (stored == null) return false;
    return PinCrypto.verify(pin, stored);
  }

  /// Call after a successful PIN entry (app lock or sensitive unlock).
  Future<void> markPinUnlock([DateTime? at]) async {
    final stamp = (at ?? DateTime.now()).toUtc().toIso8601String();
    await LocalStorage.setString(AppConstants.lastPinUnlockAtKey, stamp);
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    if (value && !hasPin) return;
    await LocalStorage.setBool(AppConstants.lockEnabledKey, value);
    if (!value) {
      await LocalStorage.setBool(AppConstants.biometricEnabledKey, false);
    }
    notifyListeners();
  }

  Future<void> setBiometricEnabled(bool value) async {
    if (value && (!hasPin || !isEnabled)) return;
    await LocalStorage.setBool(AppConstants.biometricEnabledKey, value);
    notifyListeners();
  }

  Future<void> setWeeklyPinEnabled(bool value) async {
    await LocalStorage.setBool(AppConstants.weeklyPinEnabledKey, value);
    notifyListeners();
  }

  Future<void> setLockOnResume(bool value) async {
    await LocalStorage.setBool(AppConstants.lockOnResumeKey, value);
    notifyListeners();
  }

  Future<void> setProtectAccountBalances(bool value) async {
    if (value && !hasPin) return;
    await LocalStorage.setBool(AppConstants.protectAccountBalancesKey, value);
    notifyListeners();
  }

  Future<void> clearPin() async {
    await LocalStorage.remove(AppConstants.pinHashKey);
    await LocalStorage.remove(AppConstants.lastPinUnlockAtKey);
    await LocalStorage.setBool(AppConstants.lockEnabledKey, false);
    await LocalStorage.setBool(AppConstants.biometricEnabledKey, false);
    await LocalStorage.setBool(AppConstants.protectAccountBalancesKey, false);
    notifyListeners();
  }
}
