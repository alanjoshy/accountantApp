// More tab body.

import 'package:flutter/material.dart';

import '../../../../app/theme/app_text_styles.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      bottom: false,
      child: Center(
        child: Text('More', style: AppTextStyles.title),
      ),
    );
  }
}
