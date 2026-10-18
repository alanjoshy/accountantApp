// Rebuild inbox + OS schedules from live stores.

import '../../../app/currency/currency_controller.dart';
import '../../accounts/data/account_store.dart';
import '../../auth/data/app_lock_store.dart';
import '../../auth/domain/sensitive_access_session.dart';
import '../../budgets/data/budget_store.dart';
import '../../debts/data/debt_store.dart';
import '../../planned/data/planned_reserve_store.dart';
import '../../scheduled/data/scheduled_payment_store.dart';
import '../../settings/data/app_settings_store.dart';
import '../../transactions/data/transaction_store.dart';
import '../data/notification_inbox_store.dart';
import '../data/notification_service.dart';
import 'reminder_engine.dart';

class ReminderSync {
  ReminderSync._();

  static Future<void> refresh() async {
    final settings = AppSettingsStore.instance.settings;
    final format = CurrencyController.instance.format;
    final lock = AppLockStore.instance;

    final active = ReminderEngine.evaluateActive(
      settings: settings,
      transactions: TransactionStore.instance.transactions,
      budgets: BudgetStore.instance.budgets,
      debts: DebtStore.instance.open,
      scheduledPayments: ScheduledPaymentStore.instance.all,
      accounts: AccountStore.instance.accounts,
      plannedReserves: PlannedReserveStore.instance.active,
      formatMoney: format,
      hasPin: lock.hasPin,
      protectAccountBalances: lock.protectAccountBalances,
      revealBalances: SensitiveAccessSession.instance.isRevealed,
    );

    await NotificationInboxStore.instance.syncActive(active);

    final schedules = ReminderEngine.evaluateSchedules(
      settings: settings,
      transactions: TransactionStore.instance.transactions,
      budgets: BudgetStore.instance.budgets,
      debts: DebtStore.instance.open,
      scheduledPayments: ScheduledPaymentStore.instance.all,
      formatMoney: format,
    );

    if (settings.notificationsEnabled) {
      await NotificationService.instance.reschedule(schedules);
    } else {
      await NotificationService.instance.cancelAll();
    }
  }
}
