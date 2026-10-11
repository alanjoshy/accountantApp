// Startup wiring.

import '../core/storage/local_storage.dart';
import 'currency/currency_controller.dart';
import 'theme/theme_controller.dart';

Future<void> bootstrap() async {
  await LocalStorage.init();
  ThemeController.instance.load();
  CurrencyController.instance.load();
}
