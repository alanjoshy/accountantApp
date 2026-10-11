// Persisted app-lock PIN.

import '../../../core/constants/app_constants.dart';
import '../../../core/storage/local_storage.dart';
import '../domain/pin_crypto.dart';

class AppLockStore {
  AppLockStore._();

  static String? get pinHash =>
      LocalStorage.getString(AppConstants.pinHashKey);

  static bool get hasPin => pinHash != null && pinHash!.isNotEmpty;

  static bool get isEnabled =>
      LocalStorage.getBool(AppConstants.lockEnabledKey) ?? hasPin;

  static Future<void> setPin(String pin) async {
    final hashed = PinCrypto.hash(pin);
    await LocalStorage.setString(AppConstants.pinHashKey, hashed);
    await LocalStorage.setBool(AppConstants.lockEnabledKey, true);
  }

  static bool verify(String pin) {
    final stored = pinHash;
    if (stored == null) return false;
    return PinCrypto.verify(pin, stored);
  }
}
