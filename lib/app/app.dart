// Root MaterialApp.

import 'package:flutter/material.dart';

import 'router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

class AccountantApp extends StatelessWidget {
  const AccountantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'Accountant',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeController.instance.mode,
          initialRoute: AppRouter.lock,
          onGenerateRoute: AppRouter.onGenerateRoute,
        );
      },
    );
  }
}
