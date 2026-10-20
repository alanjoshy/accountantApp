// Startup wiring.

import 'package:flutter/foundation.dart';

import '../core/storage/local_storage.dart';
import '../features/accounts/data/account_store.dart';
import '../features/accounts/domain/account_style.dart';
import '../features/budgets/data/budget_store.dart';
import '../features/debts/data/debt_store.dart';
import '../features/jars/data/jar_store.dart';
import '../features/reminders/data/notification_inbox_store.dart';
import '../features/reminders/data/notification_service.dart';
import '../features/reminders/domain/reminder_sync.dart';
import '../features/planned/data/planned_reserve_store.dart';
import '../features/scheduled/data/scheduled_payment_store.dart';
import '../features/settings/data/app_settings_store.dart';
import '../features/transactions/data/transaction_store.dart';
import 'currency/currency_controller.dart';
import 'theme/theme_controller.dart';

void _trySync(String label, void Function() fn) {
  try {
    fn();
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('bootstrap $label failed: $e\n$st');
    }
  }
}

Future<void> _tryAsync(String label, Future<void> Function() fn) async {
  try {
    await fn();
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('bootstrap $label failed: $e\n$st');
    }
  }
}

Future<void> bootstrap() async {
  await LocalStorage.init();
  _trySync('theme', ThemeController.instance.load);
  _trySync('currency', CurrencyController.instance.load);
  _trySync('jars', JarStore.instance.load);
  _trySync('debts', DebtStore.instance.load);
  _trySync('accounts', AccountStore.instance.load);
  await _tryAsync('account seed', AccountStore.instance.ensureSeeded);
  _trySync('transactions', TransactionStore.instance.load);
  _trySync('settings', AppSettingsStore.instance.load);
  // Prefer bank as default debit account when unset.
  if (AppSettingsStore.instance.defaultAccountId == null &&
      AccountStore.instance.accounts.isNotEmpty) {
    final bank = AccountStore.instance.accounts
        .where((a) => a.kind == AccountKind.bank)
        .firstOrNull;
    await _tryAsync(
      'default account',
      () => AppSettingsStore.instance.setDefaultAccountId(
        bank?.id ?? AccountStore.instance.accounts.first.id,
      ),
    );
  }
  _trySync('budgets', BudgetStore.instance.load);
  await _tryAsync(
    'budget seed',
    BudgetStore.instance.ensureDefaultCategories,
  );
  await _tryAsync('budget cycles', BudgetStore.instance.syncCycles);
  _trySync('scheduled', ScheduledPaymentStore.instance.load);
  _trySync('planned', PlannedReserveStore.instance.load);
  _trySync('inbox', NotificationInboxStore.instance.load);

  // Notifications must not block first paint — failures stay local.
  try {
    await NotificationService.instance.init().timeout(
      const Duration(seconds: 8),
    );
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('NotificationService.init failed: $e\n$st');
    }
  }

  // Reminder sync is best-effort; never prevent runApp.
  try {
    await ReminderSync.refresh().timeout(const Duration(seconds: 8));
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('ReminderSync.refresh failed: $e\n$st');
    }
  }
}
