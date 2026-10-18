import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:accountant/app/bootstrap.dart';
import 'package:accountant/core/storage/local_storage.dart';
import 'package:accountant/features/auth/data/app_lock_store.dart';
import 'package:accountant/features/auth/domain/app_session.dart';
import 'package:accountant/features/auth/domain/sensitive_access_session.dart';
import 'package:accountant/features/home/domain/remember_tips.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    LocalStorage.resetForTest();
    await bootstrap();
    AppSession.instance.reset();
    SensitiveAccessSession.instance.reset();
  });

  test('app lock prefs and session unlock', () async {
    final lock = AppLockStore.instance;
    expect(lock.hasPin, isFalse);
    expect(lock.shouldShowLock, isFalse);

    await lock.setPin('2468');
    expect(lock.hasPin, isTrue);
    expect(lock.isEnabled, isTrue);
    expect(lock.shouldShowLock, isTrue);
    expect(lock.verify('2468'), isTrue);
    expect(lock.verify('0000'), isFalse);

    await lock.setBiometricEnabled(true);
    expect(lock.biometricEnabled, isTrue);
    // setPin marks a PIN unlock, so biometrics are allowed until weekly due.
    expect(lock.canUseBiometricUnlock, isTrue);
    expect(lock.requiresWeeklyPin(), isFalse);

    await lock.setProtectAccountBalances(true);
    expect(lock.protectAccountBalances, isTrue);
    expect(SensitiveAccessSession.instance.isRevealed, isFalse);

    SensitiveAccessSession.instance.reveal();
    expect(SensitiveAccessSession.instance.isRevealed, isTrue);

    AppSession.instance.unlock();
    expect(AppSession.instance.isUnlocked, isTrue);
    AppSession.instance.lock();
    expect(AppSession.instance.isUnlocked, isFalse);
    expect(SensitiveAccessSession.instance.isRevealed, isFalse);
  });

  test('weekly PIN blocks biometrics after 7 days', () async {
    final lock = AppLockStore.instance;
    await lock.setPin('2468');
    await lock.setBiometricEnabled(true);
    expect(lock.weeklyPinEnabled, isTrue);

    final old = DateTime.now().subtract(const Duration(days: 8));
    await lock.markPinUnlock(old);
    expect(lock.requiresWeeklyPin(), isTrue);
    expect(lock.canUseBiometricUnlock, isFalse);

    await lock.markPinUnlock(DateTime.now());
    expect(lock.requiresWeeklyPin(), isFalse);
    expect(lock.canUseBiometricUnlock, isTrue);

    await lock.setWeeklyPinEnabled(false);
    await lock.markPinUnlock(old);
    expect(lock.requiresWeeklyPin(), isFalse);
    expect(lock.canUseBiometricUnlock, isTrue);
  });

  test('shouldRelock respects grace and settings', () async {
    await AppLockStore.instance.setPin('1357');
    await AppLockStore.instance.setLockOnResume(true);
    AppSession.instance.unlock();

    expect(AppSession.instance.shouldRelock(), isFalse);
    AppSession.instance.markPaused();
    expect(
      AppSession.instance.shouldRelock(grace: Duration.zero),
      isTrue,
    );

    await AppLockStore.instance.setLockOnResume(false);
    expect(
      AppSession.instance.shouldRelock(grace: Duration.zero),
      isFalse,
    );
  });

  test('buildSecurityTips', () {
    final noPin = buildSecurityTips(
      hasPin: false,
      protectAccountBalances: false,
      hasAccounts: true,
    );
    expect(noPin.single.id, 'security-no-pin');

    final protect = buildSecurityTips(
      hasPin: true,
      protectAccountBalances: false,
      hasAccounts: true,
    );
    expect(protect.single.id, 'security-protect-balances');

    final ok = buildSecurityTips(
      hasPin: true,
      protectAccountBalances: true,
      hasAccounts: true,
    );
    expect(ok, isEmpty);
  });
}
