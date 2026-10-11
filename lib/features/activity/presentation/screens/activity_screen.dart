// Activity tab body.

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return SafeArea(
      bottom: false,
      child: Center(
        child: Text(
          'Activity',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
      ),
    );
  }
}
