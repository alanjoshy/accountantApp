// Named routes.

import 'package:flutter/material.dart';

import '../core/navigation/app_tab.dart';
import '../features/auth/presentation/screens/lock_screen.dart';
import '../features/shell/presentation/screens/main_shell.dart';

class AppRouter {
  AppRouter._();

  static const lock = '/lock';
  static const home = '/home';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case lock:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const LockScreen(),
        );
      case home:
        final tab = settings.arguments is AppTab
            ? settings.arguments as AppTab
            : AppTab.home;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => MainShell(initialTab: tab),
        );
      default:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const LockScreen(),
        );
    }
  }
}
