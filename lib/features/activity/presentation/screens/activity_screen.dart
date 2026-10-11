// Activity tab body.

import 'package:flutter/material.dart';

import '../../../../app/theme/app_text_styles.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      bottom: false,
      child: Center(
        child: Text('Activity', style: AppTextStyles.title),
      ),
    );
  }
}
