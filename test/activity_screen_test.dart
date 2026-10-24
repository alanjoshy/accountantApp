// Activity tab: infinite-scroll paging + month-pulse daily bars.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:accountant/app/bootstrap.dart';
import 'package:accountant/app/theme/app_theme.dart';
import 'package:accountant/core/navigation/app_tab.dart';
import 'package:accountant/core/storage/local_storage.dart';
import 'package:accountant/features/activity/domain/activity_logic.dart';
import 'package:accountant/features/activity/presentation/widgets/daily_spend_bar_chart.dart';
import 'package:accountant/features/auth/domain/app_session.dart';
import 'package:accountant/features/auth/domain/biometric_auth.dart';
import 'package:accountant/features/auth/domain/sensitive_access_session.dart';
import 'package:accountant/features/budgets/data/budget_store.dart';
import 'package:accountant/features/settings/data/app_settings_store.dart';
import 'package:accountant/features/shell/presentation/screens/main_shell.dart';
import 'package:accountant/features/transactions/data/transaction.dart';
import 'package:accountant/features/transactions/data/transaction_store.dart';

MoneyTransaction _tx({
  required String id,
  required String title,
  required String date,
  double amount = 10,
}) {
  return MoneyTransaction(
    id: id,
    title: title,
    amount: amount,
    type: TransactionType.expense,
    category: 'Food',
    date: date,
    createdAt: date,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    LocalStorage.resetForTest();
    TransactionStore.instance.unloadForTest();
    await bootstrap();
    AppSession.instance.reset();
    SensitiveAccessSession.instance.reset();
    BiometricAuth.instance.debugClearOverride();
  });

  testWidgets('daily spending uses month-pulse bars for the selected cycle', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 900));

    await AppSettingsStore.instance.setMonthlyIncome(10000);
    await BudgetStore.instance.add(category: 'Food', limit: 3100);
    await TransactionStore.instance.replaceAll([
      _tx(
        id: 'snack',
        title: 'Snack',
        amount: 50,
        date: DateTime.now().toIso8601String(),
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const MainShell(initialTab: AppTab.activity),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DailySpendBarChart), findsOneWidget);
    expect(find.text('Daily spending'), findsOneWidget);
    expect(find.text('DAILY'), findsOneWidget);
    expect(find.textContaining('Allowance'), findsOneWidget);
    expect(find.text('Grey left · red over'), findsOneWidget);
    expect(find.text('Snack'), findsOneWidget);
  });

  testWidgets('activity list pages in as the user scrolls', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 900));

    final now = DateTime.now();
    await TransactionStore.instance.replaceAll([
      for (var day = 0; day < 25; day++)
        for (var n = 0; n < 4; n++)
          _tx(
            id: 'd${day}n$n',
            title: 'D${day}N$n',
            date: now.subtract(Duration(days: day, hours: n)).toIso8601String(),
          ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const MainShell(initialTab: AppTab.activity),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('D0N0'), findsOneWidget);
    expect(find.text('D20N0'), findsNothing);
    expect(find.text('Loading more…'), findsOneWidget);

    final groups = groupTransactionsByDay(
      TransactionStore.instance.transactions,
    );
    final firstPage = paginateDayGroups(groups, kActivityPageSize);
    expect(firstPage.hasMore, isTrue);

    final scrollable = find
        .descendant(
          of: find.byKey(const ValueKey('activity-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    for (var i = 0; i < 20; i++) {
      if (find.text('D20N0').evaluate().isNotEmpty) break;
      final state = tester.state<ScrollableState>(scrollable);
      state.position.jumpTo(state.position.maxScrollExtent);
      await tester.pump();
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.text('D20N0'), findsOneWidget);
  });
}
