// Shared page transitions — PageRoute only (no blocking overlays).

import 'package:flutter/material.dart';

/// Soft fade + slight horizontal slide. Use for stack pushes (More → …).
class AppPageRoute<T> extends PageRouteBuilder<T> {
  AppPageRoute({
    required WidgetBuilder builder,
    super.settings,
    this.fadeOnly = false,
  }) : super(
          transitionDuration: const Duration(milliseconds: 230),
          reverseTransitionDuration: const Duration(milliseconds: 230),
          opaque: true,
          barrierDismissible: false,
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            if (MediaQuery.disableAnimationsOf(context)) return child;

            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );

            final faded = FadeTransition(opacity: curved, child: child);
            if (fadeOnly) return faded;

            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.045, 0),
                end: Offset.zero,
              ).animate(curved),
              child: faded,
            );
          },
        );

  /// Lock ↔ home style: opacity only (no slide).
  final bool fadeOnly;
}

Future<T?> appPush<T extends Object?>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(
    AppPageRoute<T>(builder: (_) => page),
  );
}

Future<T?> appPushReplacement<T extends Object?, TO extends Object?>(
  BuildContext context,
  Widget page, {
  TO? result,
}) {
  return Navigator.of(context).pushReplacement<T, TO>(
    AppPageRoute<T>(builder: (_) => page, fadeOnly: true),
    result: result,
  );
}
