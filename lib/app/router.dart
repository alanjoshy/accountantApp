import 'package:flutter/material.dart';

import '../features/auth/presentation/screens/sign_in_screen.dart';

class AppRouter {
  static const String signIn = '/sign-in';

  static Map<String, WidgetBuilder> get routes {
    return {
      signIn: (context) => const SignInScreen(),
    };
  }
}