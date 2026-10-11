// App-wide config values.

import 'environment.dart';

class AppConfig {
  AppConfig._();

  static const appName = 'Accountant';
  static const Environment environment = Environment.dev;

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.example.com',
  );

  static bool get isDev => environment == Environment.dev;
}
