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
import 'package:accountant/core/storage/local_storage.dart';
import 'package:accountant/core/widgets/app_toast.dart';
import 'package:accountant/features/auth/data/app_lock_store.dart';
import 'package:accountant/features/auth/domain/app_session.dart';
import 'package:accountant/features/auth/domain/biometric_auth.dart';
import 'package:accountant/features/auth/domain/sensitive_access_session.dart';
import 'package:accountant/features/auth/presentation/screens/lock_screen.dart';
import 'package:accountant/features/budgets/data/budget_store.dart';
import 'package:accountant/features/home/presentation/widgets/budget_balance_card.dart';
import 'package:accountant/features/settings/data/app_settings_store.dart';
import 'package:accountant/features/shell/presentation/screens/main_shell.dart';
import 'package:accountant/features/transactions/data/transaction.dart';
import 'package:accountant/features/transactions/data/transaction_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    LocalStorage.resetForTest();
    await bootstrap();
    AppSession.instance.reset();
    SensitiveAccessSession.instance.reset();
    BiometricAuth.instance.debugClearOverride();
    await ThemeController.instance.setMode(ThemeMode.system);
    AppToast.dismiss();
  });

  tearDown(AppToast.dismiss);

  testWidgets('opens home when app lock is off', (tester) async {
    await tester.pumpWidget(const AccountantApp());
    await tester.pumpAndSettle();

    expect(find.text('Account balance'), findsOneWidget);
    expect(find.text('Set your PIN'), findsNothing);
  });

  testWidgets('shows lock screen when PIN is enabled', (tester) async {
    await AppLockStore.instance.setPin('1234');
    AppSession.instance.reset();
    BiometricAuth.instance.debugOverride(
      available: () async => false,
      authenticate: ({required reason}) async => false,
    );

    await tester.pumpWidget(const AccountantApp());
    await tester.pumpAndSettle();

    expect(find.text('Accountant is locked'), findsOneWidget);
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
    expect(find.text('PERSONAL FINANCE'), findsOneWidget);
    expect(find.byTooltip('Notifications'), findsOneWidget);
    expect(find.byTooltip('Profile'), findsOneWidget);
    expect(find.text('Account balance'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Expense'), findsOneWidget);
    expect(find.text('0d'), findsOneWidget);
    // No battery until income or allocated budgets exist.
    expect(find.text('LEFT'), findsNothing);
    expect(find.text('Transactions'), findsOneWidget);
    expect(find.text('Income entries'), findsOneWidget);
    expect(find.text('Things to remember'), findsOneWidget);
    // Seeded accounts / unplanned budget / daily log / security tips.
    expect(
      find.textContaining('Low balance').evaluate().isNotEmpty ||
          find.textContaining('Set a PIN').evaluate().isNotEmpty ||
          find.textContaining('isn’t planned').evaluate().isNotEmpty ||
          find.textContaining('today’s transactions').evaluate().isNotEmpty ||
          find.text('Track a few spends').evaluate().isNotEmpty,
      isTrue,
    );
    expect(find.text('Month pulse'), findsOneWidget);
    expect(find.text('SPENDING'), findsOneWidget);
    expect(find.textContaining('days with activity'), findsOneWidget);
    expect(find.textContaining('No spend logged this month yet'), findsOneWidget);
    expect(find.textContaining('No income logged this month yet'), findsOneWidget);
    // Live budget balance hides until category limits exist.
    expect(find.text('Budget balance'), findsNothing);
  });

  testWidgets(
    'budget balance toggle is compact, weekly-first, weekly default',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));

      await BudgetStore.instance.add(category: 'Food', limit: 3100);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: SingleChildScrollView(child: BudgetBalanceCard()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Budget balance'), findsOneWidget);
      expect(find.text('Weekly'), findsOneWidget);
      expect(find.text('Monthly'), findsOneWidget);
      expect(find.textContaining('This week'), findsOneWidget);

      final weeklyLeft = tester.getTopLeft(find.text('Weekly')).dx;
      final monthlyLeft = tester.getTopLeft(find.text('Monthly')).dx;
      expect(weeklyLeft, lessThan(monthlyLeft));

      final cardWidth = tester.getSize(find.byType(BudgetBalanceCard)).width;
      final toggleSpan =
          tester.getRect(find.text('Monthly')).right -
          tester.getRect(find.text('Weekly')).left;
      expect(toggleSpan, lessThan(cardWidth * 0.7));

      await tester.tap(find.text('Monthly'));
      await tester.pump();
      expect(
        find.text('Allocated, spent, and remaining per category'),
        findsOneWidget,
      );
    },
  );

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

    expect(find.text('Scheduled payments'), findsOneWidget);
    final moreScroll = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Alan Joshy'),
      80,
      scrollable: moreScroll,
    );
    expect(find.text('Alan Joshy'), findsOneWidget);
    expect(find.text('LinkedIn'), findsOneWidget);
    expect(find.text('Website'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Settings'),
      80,
      scrollable: moreScroll,
    );
    await tester.drag(moreScroll, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings').hitTestable().first);
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

    final moreScroll = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Settings'),
      80,
      scrollable: moreScroll,
    );
    await tester.drag(moreScroll, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings').hitTestable().first);
    await tester.pumpAndSettle();

    final settingsScroll = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('currency-dropdown')),
      120,
      scrollable: settingsScroll,
    );
    expect(find.text('CURRENCY'), findsOneWidget);
    expect(find.byKey(const ValueKey('currency-dropdown')), findsOneWidget);
    expect(find.text('Indian Rupee'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('currency-dropdown')),
    );
    await tester.pumpAndSettle();
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

    // Fresh home — currency ListenableBuilder above remounts the shell.
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const MainShell(),
      ),
    );
    await tester.pumpAndSettle();

    // Amounts are visible by default on the balance card.
    expect(find.text('€0'), findsWidgets);
    expect(find.byIcon(Icons.visibility_off_rounded), findsOneWidget);
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
    view.physicalSize = const Size(960, 3000);
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

    final moreScroll = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Settings'),
      120,
      scrollable: moreScroll,
    );
    // Clear floating dock overlap after large text scale.
    await tester.drag(moreScroll, const Offset(0, -160));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings').hitTestable().first);
    await tester.pumpAndSettle();

    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dock add saves transaction visible on Activity with filter/delete', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 900));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const MainShell(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Add spend'), findsOneWidget);

    final fields = find.byType(TextField);
    expect(fields, findsAtLeastNWidgets(2));
    // Amount first, then title (web field order); Food is default category.
    await tester.enterText(fields.at(0), '45');
    await tester.enterText(fields.at(1), 'Coffee');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Save'));
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('Transaction saved.'), findsOneWidget);
    AppToast.dismiss();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(TransactionStore.instance.count, 1);

    await tester.tap(find.byIcon(Icons.timeline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Coffee'), findsOneWidget);
    expect(find.text('Recent activity'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Expense'));
    await tester.pumpAndSettle();
    expect(find.text('Coffee'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Income'));
    await tester.pumpAndSettle();
    expect(find.text('Coffee'), findsNothing);
    expect(find.textContaining('No transactions match'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'All').first);
    await tester.pumpAndSettle();
    expect(find.text('Coffee'), findsOneWidget);

    // Collapse filters so selection actions stay on-screen.
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.check_box_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coffee'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Delete 1 transaction'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Delete').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('Coffee'), findsNothing);
    expect(TransactionStore.instance.count, 0);
    AppToast.dismiss();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('settings tag appears in Activity filters; detail edits list', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 900));

    await AppSettingsStore.instance.addTag('work');
    await TransactionStore.instance.add(
      title: 'Lunch',
      amount: 120,
      type: TransactionType.expense,
      category: 'Food',
      date: DateTime.now().toIso8601String(),
      tags: const ['work'],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const MainShell(initialTab: AppTab.more),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tags'), findsOneWidget);
    await tester.tap(find.text('Tags'));
    await tester.pumpAndSettle();
    expect(find.text('#work'), findsOneWidget);

    await tester.tap(find.text('More').hitTestable().first);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.timeline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Lunch'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ChoiceChip, '#work'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();

    final activityScroll = find
        .descendant(
          of: find.byKey(const ValueKey('activity-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Lunch'),
      120,
      scrollable: activityScroll,
    );
    await tester.ensureVisible(find.text('Lunch'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lunch'));
    await tester.pumpAndSettle();
    expect(find.text('Edit transaction'), findsOneWidget);
    // Title field is prefilled with the transaction name.
    await tester.enterText(find.widgetWithText(TextField, 'Lunch'), 'Team lunch');
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Save changes'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('Team lunch'), findsOneWidget);
    expect(find.text('Lunch'), findsNothing);
    AppToast.dismiss();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('budget limit shows daily allowance on Activity chart', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 900));

    await AppSettingsStore.instance.setMonthlyIncome(10000);
    await BudgetStore.instance.add(category: 'Food', limit: 3100);
    await TransactionStore.instance.add(
      title: 'Snack',
      amount: 50,
      type: TransactionType.expense,
      category: 'Food',
      date: DateTime.now().toIso8601String(),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const MainShell(initialTab: AppTab.activity),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Snack'), findsOneWidget);
    expect(find.textContaining('Allowance'), findsOneWidget);
    expect(find.text('Daily spending'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.pie_chart_rounded));
    await tester.pumpAndSettle();
    expect(find.text('This cycle'), findsOneWidget);
    expect(find.text('Food'), findsWidgets);
    expect(find.text('Allocate to categories'), findsOneWidget);
  });

  testWidgets('more opens jar, creates and deletes a savings jar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const MainShell(initialTab: AppTab.more),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Jar'), findsOneWidget);
    await tester.tap(find.text('Jar'));
    await tester.pumpAndSettle();

    expect(find.text('Jars'), findsOneWidget);
    expect(find.text('No jars yet'), findsOneWidget);
    expect(find.text('Coming soon'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_circle_outline_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Create jar'), findsWidgets);
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(3));
    await tester.enterText(fields.at(0), 'Emergency');
    await tester.enterText(fields.at(1), '1000');
    await tester.enterText(fields.at(2), '250');
    await tester.tap(find.widgetWithText(FilledButton, 'Create jar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Emergency'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);
    expect(find.text('No jars yet'), findsNothing);
    AppToast.dismiss();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Delete jar?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('No jars yet'), findsOneWidget);
    expect(find.text('Emergency'), findsNothing);
    AppToast.dismiss();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('more opens accounts and shows payment modes', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MainShell()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.grid_view_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accounts & payments'));
    await tester.pumpAndSettle();

    expect(find.text('Accounts & payments'), findsWidgets);
    expect(find.text('Total balance'), findsOneWidget);
    expect(find.text('Primary bank'), findsOneWidget);
    expect(find.text('In-hand cash'), findsWidgets);
    expect(find.text('UPI'), findsOneWidget);
    expect(find.text('PAYMENT MODES'), findsOneWidget);
  });
}
