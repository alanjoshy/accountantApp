// Activity tab body.

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Center(
      child: Text(
        'No activity yet',
        style: TextStyle(
          fontSize: 15,
          color: colors.textMuted,
        ),
      ),
    );
  }
}
