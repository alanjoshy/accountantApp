// Startup wiring.

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

Future<void> bootstrap() async {
  await LocalStorage.init();
  ThemeController.instance.load();
  CurrencyController.instance.load();
  JarStore.instance.load();
  DebtStore.instance.load();
  AccountStore.instance.load();
  await AccountStore.instance.ensureSeeded();
  TransactionStore.instance.load();
  AppSettingsStore.instance.load();
  // Prefer bank as default debit account when unset.
  if (AppSettingsStore.instance.defaultAccountId == null &&
      AccountStore.instance.accounts.isNotEmpty) {
    final bank = AccountStore.instance.accounts
        .where((a) => a.kind == AccountKind.bank)
        .firstOrNull;
    await AppSettingsStore.instance.setDefaultAccountId(
      bank?.id ?? AccountStore.instance.accounts.first.id,
    );
  }
  BudgetStore.instance.load();
  await BudgetStore.instance.ensureDefaultCategories();
  await BudgetStore.instance.syncCycles();
  ScheduledPaymentStore.instance.load();
  PlannedReserveStore.instance.load();
  NotificationInboxStore.instance.load();
  await NotificationService.instance.init();
  await ReminderSync.refresh();
}
