// Create / restore Accountant backup snapshots against live stores.

import '../../../core/constants/app_constants.dart';
import '../../../core/storage/local_storage.dart';
import '../../accounts/data/account_store.dart';
import '../../accounts/domain/account_style.dart';
import '../../auth/domain/sensitive_access_session.dart';
import '../../budgets/data/budget_store.dart';
import '../../debts/data/debt_store.dart';
import '../../jars/data/jar_store.dart';
import '../../planned/data/planned_reserve_store.dart';
import '../../reminders/data/notification_inbox_store.dart';
import '../../reminders/domain/reminder_sync.dart';
import '../../scheduled/data/scheduled_payment_store.dart';
import '../../settings/data/app_settings.dart';
import '../../settings/data/app_settings_store.dart';
import '../../transactions/data/transaction_store.dart';
import 'backup_snapshot.dart';

/// Prefs keys wiped on factory reset (keeps PIN / theme / currency).
const _wipeDataKeys = <String>[
  AppConstants.transactionsKey,
  AppConstants.budgetsKey,
  AppConstants.budgetsSeededKey,
  AppConstants.budgetsPermanentKey,
  AppConstants.jarsKey,
  AppConstants.appSettingsKey,
  AppConstants.accountsKey,
  AppConstants.accountsSeededKey,
  AppConstants.debtsKey,
  AppConstants.scheduledPaymentsKey,
  AppConstants.plannedReservesKey,
  AppConstants.notificationInboxKey,
];

class BackupService {
  BackupService._();

  static BackupSnapshot createSnapshot() {
    final settings = AppSettingsStore.instance.settings;
    final settingsRow = <String, dynamic>{
      'id': 'app',
      ...settings.toJson(),
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };
    return BackupSnapshot(
      exportedAt: DateTime.now().toUtc().toIso8601String(),
      transactions: TransactionStore.instance.transactions,
      budgets: BudgetStore.instance.budgets,
      jars: JarStore.instance.jars,
      settings: [settingsRow],
      accounts: AccountStore.instance.accounts,
      scheduledPayments: ScheduledPaymentStore.instance.all,
      plannedReserves: PlannedReserveStore.instance.all,
      debts: DebtStore.instance.debts,
    );
  }

  /// Replace all local money data with [snapshot] (web restore parity).
  static Future<void> restoreSnapshot(BackupSnapshot snapshot) async {
    await AccountStore.instance.replaceAll(snapshot.accounts);
    await TransactionStore.instance.replaceAll(snapshot.transactions);
    await BudgetStore.instance.replaceAll(snapshot.budgets);
    await JarStore.instance.replaceAll(snapshot.jars);
    await DebtStore.instance.replaceAll(snapshot.debts);
    await ScheduledPaymentStore.instance.replaceAll(snapshot.scheduledPayments);
    await PlannedReserveStore.instance.replaceAll(snapshot.plannedReserves);

    final merged = mergeSettingsFromBackup(
      AppSettingsStore.instance.settings,
      snapshot.settings,
    );
    await AppSettingsStore.instance.replace(merged);

    // Must match AccountStore.ensureSeeded() which reads a bool, not a string.
    // Writing '1' here used to throw on the next launch and skip transaction load.
    await LocalStorage.setBool(AppConstants.accountsSeededKey, true);
    await LocalStorage.setString(AppConstants.budgetsSeededKey, '1');
    await LocalStorage.setString(AppConstants.budgetsPermanentKey, '1');

    await ReminderSync.refresh();
  }

  static Future<BackupSnapshot> restoreFromJsonText(String text) async {
    final snapshot = parseBackupJson(text);
    await restoreSnapshot(snapshot);
    return snapshot;
  }

  /// Wipe money data and re-seed a fresh empty workspace.
  /// Keeps app lock PIN, theme, and currency preferences.
  static Future<void> wipeAllData() async {
    await LocalStorage.removeAll(_wipeDataKeys);

    await TransactionStore.instance.replaceAll(const []);
    await BudgetStore.instance.replaceAll(const []);
    await JarStore.instance.replaceAll(const []);
    await DebtStore.instance.replaceAll(const []);
    await ScheduledPaymentStore.instance.replaceAll(const []);
    await PlannedReserveStore.instance.replaceAll(const []);
    await AccountStore.instance.replaceAll(const []);
    await NotificationInboxStore.instance.clearAll();
    await AppSettingsStore.instance.replace(const AppSettings());

    await AccountStore.instance.ensureSeeded();
    await BudgetStore.instance.ensureDefaultCategories();
    await BudgetStore.instance.migrateToPermanentCategories();
    await BudgetStore.instance.syncCycles();

    if (AppSettingsStore.instance.defaultAccountId == null &&
        AccountStore.instance.accounts.isNotEmpty) {
      final bank = AccountStore.instance.accounts
          .where((a) => a.kind == AccountKind.bank)
          .firstOrNull;
      await AppSettingsStore.instance.setDefaultAccountId(
        bank?.id ?? AccountStore.instance.accounts.first.id,
      );
    }

    SensitiveAccessSession.instance.lock();
    await ReminderSync.refresh();
  }
}
