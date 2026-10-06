import 'package:flutter/material.dart';

import 'router.dart';
import 'theme/app_theme.dart';

class AccountantApp extends StatelessWidget {
  const AccountantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Accountant',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: AppRouter.signIn,
      routes: AppRouter.routes,
    );
  }
}