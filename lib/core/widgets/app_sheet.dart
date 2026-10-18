// Shared modal bottom sheet chrome (safe PageRoute — not a custom overlay).

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: AppColors.of(context).surfaceElevated,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: builder,
  );
}
