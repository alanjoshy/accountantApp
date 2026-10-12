// Startup wiring.

import '../core/storage/local_storage.dart';
import '../features/budgets/data/budget_store.dart';
import '../features/jars/data/jar_store.dart';
import '../features/settings/data/app_settings_store.dart';
import '../features/transactions/data/transaction_store.dart';
import 'currency/currency_controller.dart';
import 'theme/theme_controller.dart';

Future<void> bootstrap() async {
  await LocalStorage.init();
  ThemeController.instance.load();
  CurrencyController.instance.load();
  JarStore.instance.load();
  TransactionStore.instance.load();
  AppSettingsStore.instance.load();
  BudgetStore.instance.load();
  await BudgetStore.instance.syncCycles();
}
