// Startup wiring.

import '../core/storage/local_storage.dart';

Future<void> bootstrap() async {
  await LocalStorage.init();
}
