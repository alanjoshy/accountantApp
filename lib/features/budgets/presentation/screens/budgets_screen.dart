// Budgets tab body.

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Center(
      child: Text(
        'No budgets yet',
        style: TextStyle(
          fontSize: 15,
          color: colors.textMuted,
        ),
      ),
    );
  }
}
