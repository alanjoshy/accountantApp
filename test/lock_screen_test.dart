// Lock screen biometric + PIN widget tests.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:accountant/app/bootstrap.dart';
import 'package:accountant/app/routes.dart';
import 'package:accountant/core/storage/local_storage.dart';
import 'package:accountant/features/auth/data/app_lock_store.dart';
import 'package:accountant/features/auth/domain/app_session.dart';
import 'package:accountant/features/auth/domain/biometric_auth.dart';
import 'package:accountant/features/auth/domain/sensitive_access_session.dart';
import 'package:accountant/features/auth/presentation/screens/lock_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    LocalStorage.resetForTest();
    await bootstrap();
    AppSession.instance.reset();
    SensitiveAccessSession.instance.reset();
    BiometricAuth.instance.debugClearOverride();
  });

  Future<void> pumpLock(WidgetTester tester, {bool tryBio = true}) {
    return tester.pumpWidget(
      MaterialApp(
        home: LockScreen(tryBiometricOnStart: tryBio),
        routes: {
          AppRoutes.home: (_) => const Scaffold(body: Text('Unlocked home')),
        },
      ),
    );
  }

  testWidgets('biometric success unlocks lock screen', (tester) async {
    await AppLockStore.instance.setPin('1234');
    await AppLockStore.instance.setBiometricEnabled(true);
    AppSession.instance.reset();
    BiometricAuth.instance.debugOverride(
      available: () async => true,
      kind: () async => BiometricKind.fingerprint,
      authenticate: ({required reason}) async => true,
    );

    await pumpLock(tester);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Accountant is locked'), findsNothing);
    expect(find.text('Unlocked home'), findsOneWidget);
    expect(AppSession.instance.isUnlocked, isTrue);
  });

  testWidgets('biometric cancel keeps PIN unlock working', (tester) async {
    await AppLockStore.instance.setPin('1234');
    await AppLockStore.instance.setBiometricEnabled(true);
    AppSession.instance.reset();
    BiometricAuth.instance.debugOverride(
      available: () async => true,
      kind: () async => BiometricKind.fingerprint,
      authenticate: ({required reason}) async => false,
    );

    await pumpLock(tester);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Accountant is locked'), findsOneWidget);
    expect(find.text('Use fingerprint'), findsOneWidget);
    expect(find.textContaining('4–6 digit PIN'), findsWidgets);

    await tester.enterText(find.byType(TextField), '1234');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(find.text('Accountant is locked'), findsNothing);
    expect(find.text('Unlocked home'), findsOneWidget);
  });

  testWidgets('weekly PIN due hides biometric unlock', (tester) async {
    final lock = AppLockStore.instance;
    await lock.setPin('1234');
    await lock.setBiometricEnabled(true);
    await lock.markPinUnlock(DateTime.now().subtract(const Duration(days: 8)));
    AppSession.instance.reset();
    var prompted = false;
    BiometricAuth.instance.debugOverride(
      available: () async => true,
      kind: () async => BiometricKind.fingerprint,
      authenticate: ({required reason}) async {
        prompted = true;
        return true;
      },
    );

    await pumpLock(tester);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(prompted, isFalse);
    expect(find.text('Accountant is locked'), findsOneWidget);
    expect(find.text('Use fingerprint'), findsNothing);
    expect(find.textContaining('Weekly PIN check'), findsOneWidget);
  });

  testWidgets('lock screen biometric button retries after cancel', (
    tester,
  ) async {
    await AppLockStore.instance.setPin('2468');
    await AppLockStore.instance.setBiometricEnabled(true);
    AppSession.instance.reset();
    var attempts = 0;
    BiometricAuth.instance.debugOverride(
      available: () async => true,
      kind: () async => BiometricKind.face,
      authenticate: ({required reason}) async {
        attempts += 1;
        return attempts > 1;
      },
    );

    await pumpLock(tester);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Accountant is locked'), findsOneWidget);
    expect(find.text('Use Face ID'), findsOneWidget);

    await tester.tap(find.text('Use Face ID'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('Unlocked home'), findsOneWidget);
  });

  testWidgets('unavailable hardware leaves PIN usable with no bio button', (
    tester,
  ) async {
    await AppLockStore.instance.setPin('1234');
    await AppLockStore.instance.setBiometricEnabled(true);
    AppSession.instance.reset();
    BiometricAuth.instance.debugOverride(
      available: () async => false,
      authenticate: ({required reason}) async => false,
    );

    await pumpLock(tester);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Accountant is locked'), findsOneWidget);
    expect(find.text('Use fingerprint'), findsNothing);
    expect(find.text('Use biometrics'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('lock screen scrolls under keyboard and landscape', (
    tester,
  ) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
      tester.view.resetPadding();
    });

    for (final setup in const [
      (Size(390, 400), 280.0),
      (Size(844, 390), 200.0),
    ]) {
      final size = setup.$1;
      final keyboard = setup.$2;
      tester.view.physicalSize = Size(size.width * 3, size.height * 3);
      tester.view.devicePixelRatio = 3;
      tester.view.padding = const FakeViewPadding(top: 141, bottom: 102);
      tester.view.viewInsets = FakeViewPadding(bottom: keyboard * 3);

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            size: size,
            padding: const EdgeInsets.only(top: 47, bottom: 34),
            viewInsets: EdgeInsets.only(bottom: keyboard),
          ),
          child: const MaterialApp(home: LockScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('Set your PIN'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
