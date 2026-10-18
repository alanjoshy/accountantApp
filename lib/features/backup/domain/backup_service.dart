// Create / restore Accountant backup snapshots against live stores.

import '../../../core/constants/app_constants.dart';
import '../../../core/storage/local_storage.dart';
import '../../accounts/data/account_store.dart';
import '../../budgets/data/budget_store.dart';
import '../../debts/data/debt_store.dart';
import '../../jars/data/jar_store.dart';
import '../../reminders/domain/reminder_sync.dart';
import '../../planned/data/planned_reserve_store.dart';
import '../../scheduled/data/scheduled_payment_store.dart';
import '../../settings/data/app_settings_store.dart';
import '../../transactions/data/transaction_store.dart';
import 'backup_snapshot.dart';

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

    await LocalStorage.setString(AppConstants.accountsSeededKey, '1');
    await LocalStorage.setString(AppConstants.budgetsSeededKey, '1');
    await LocalStorage.setString(AppConstants.budgetsPermanentKey, '1');

    await ReminderSync.refresh();
  }

  static Future<BackupSnapshot> restoreFromJsonText(String text) async {
    final snapshot = parseBackupJson(text);
    await restoreSnapshot(snapshot);
    return snapshot;
  }
}
