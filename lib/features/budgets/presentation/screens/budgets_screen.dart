// Budgets tab body.

import 'package:flutter/material.dart';

import '../../../../app/theme/app_text_styles.dart';

class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      bottom: false,
      child: Center(
        child: Text('Budgets', style: AppTextStyles.title),
      ),
    );
  }
}
