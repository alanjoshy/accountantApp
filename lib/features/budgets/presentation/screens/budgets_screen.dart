// Budgets tab body.

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return SafeArea(
      bottom: false,
      child: Center(
        child: Text(
          'Budgets',
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