// Smoke test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:accountant/app/app.dart';
import 'package:accountant/app/bootstrap.dart';
import 'package:accountant/app/currency/app_currency.dart';
import 'package:accountant/app/currency/currency_controller.dart';
import 'package:accountant/app/theme/app_theme.dart';
import 'package:accountant/app/theme/theme_controller.dart';
import 'package:accountant/core/navigation/app_tab.dart';
import 'package:accountant/core/widgets/app_toast.dart';
import 'package:accountant/features/auth/presentation/screens/lock_screen.dart';
import 'package:accountant/features/shell/presentation/screens/main_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await bootstrap();
    await ThemeController.instance.setMode(ThemeMode.system);
    AppToast.dismiss();
  });

  tearDown(AppToast.dismiss);

  testWidgets('shows lock screen', (tester) async {
    await tester.pumpWidget(const AccountantApp());
    await tester.pumpAndSettle();

    expect(find.text('Set your PIN'), findsOneWidget);
    expect(find.textContaining('4–6 digit PIN'), findsWidgets);
  });

  testWidgets('defaults currency to Indian Rupee', (tester) async {
    expect(CurrencyController.instance.currency, AppCurrency.inr);
    expect(CurrencyController.instance.symbol, '₹');
  });

  testWidgets('home shows balance card with streak and pie', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MainShell()));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsWidgets);
    expect(find.text('Account balance'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Expense'), findsOneWidget);
    expect(find.text('0d'), findsOneWidget);
    expect(find.text('LEFT'), findsOneWidget);
    // Amounts hidden by default → percent masked like web.
    expect(find.text('••'), findsOneWidget);
  });

  testWidgets('switches tabs on phone, tablet, and desktop sizes', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final size in const [
      Size(320, 568),
      Size(390, 844),
      Size(768, 1024),
      Size(1440, 900),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(const MaterialApp(home: MainShell()));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsWidgets);
      expect(find.text('Account balance'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.timeline_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      await tester.pumpAndSettle();
      expect(find.text('Account balance'), findsNothing);
      expect(find.text('Activity'), findsWidgets);

      await tester.tap(find.byIcon(Icons.pie_chart_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Budgets'), findsWidgets);

      await tester.tap(find.byIcon(Icons.grid_view_rounded));
      await tester.pumpAndSettle();
      expect(find.text('More'), findsWidgets);

      await tester.tap(find.byIcon(Icons.home_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsWidgets);
      expect(find.text('Account balance'), findsOneWidget);
    }
  });

  testWidgets('more opens settings and toggles dark mode', (tester) async {
    await tester.pumpWidget(
      ListenableBuilder(
        listenable: ThemeController.instance,
        builder: (context, _) {
          return MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: ThemeController.instance.mode,
            home: const MainShell(initialTab: AppTab.more),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Theme'), findsOneWidget);
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(ThemeController.instance.mode, ThemeMode.dark);
    expect(find.text('Theme saved.'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
    AppToast.dismiss();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Light'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(ThemeController.instance.mode, ThemeMode.light);
    AppToast.dismiss();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('settings currency dropdown saves and updates home symbol', (
    tester,
  ) async {
    await tester.pumpWidget(
      ListenableBuilder(
        listenable: CurrencyController.instance,
        builder: (context, _) {
          return MaterialApp(
            theme: AppTheme.light,
            home: const MainShell(initialTab: AppTab.more),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('CURRENCY'), findsOneWidget);
    expect(find.byKey(const ValueKey('currency-dropdown')), findsOneWidget);
    expect(find.text('Indian Rupee'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('currency-dropdown')));
    await tester.pumpAndSettle();

    // Bottom sheet picker
    expect(find.text('Dollar'), findsWidgets);
    expect(find.text('Euro'), findsWidgets);

    await tester.tap(find.text('Euro').last);
    await tester.pumpAndSettle();

    expect(CurrencyController.instance.currency, AppCurrency.eur);
    expect(find.text('Currency saved.'), findsOneWidget);
    AppToast.dismiss();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('More').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.home_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.visibility_rounded));
    await tester.pumpAndSettle();

    expect(find.text('€0'), findsWidgets);
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

  testWidgets('home and settings tolerate narrow width and large text', (
    tester,
  ) async {
    final view = tester.view;
    view.physicalSize = const Size(960, 2100);
    view.devicePixelRatio = 3;
    view.padding = const FakeViewPadding(top: 141, bottom: 102);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
      view.resetPadding();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const MainShell(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Account balance'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.grid_view_rounded));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Settings'),
      80,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
